terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

locals {
  azurerm_logic_app_workflow_identites = merge([for logic_app_workflow_key, logic_app_workflow_value in var.logic_app_workflow : {
    for mi_key, mi_value in data.azurerm_user_assigned_identity.managed_identity :
    "${logic_app_workflow_key}-${mi_key}" => {
      managedidentity_id = mi_value.id
      name               = join("", [logic_app_workflow_value.name, "-", logic_app_workflow_value.folder])
      location           = logic_app_workflow_value.location
      rg_name            = logic_app_workflow_value.rg_name
      loganalytics       = logic_app_workflow_value.loganalytics
      storageaccount     = logic_app_workflow_value.storageaccount
      folder             = logic_app_workflow_value.folder
      #test = join("", ["foo", "bar"])
    }
  }]...)

}

data "azurerm_managed_api" "azureblob" {
  name     = "azureblob"
  location = var.AZ_LOCATION
}

data "azurerm_managed_api" "azuremonitorlogs" {
  name     = "azuremonitorlogs"
  location = var.AZ_LOCATION
}

data "azurerm_user_assigned_identity" "managed_identity" {
  for_each            = var.managed_identity
  name                = each.value["name"]
  resource_group_name = each.value["rg_name"]
}

resource "azurerm_logic_app_workflow" "logic_app_workflow" {
  for_each            = local.azurerm_logic_app_workflow_identites
  name                = each.value["name"]
  location            = each.value["location"]
  resource_group_name = each.value["rg_name"]
  enabled             = true
  identity {
    identity_ids = [
      each.value["managedidentity_id"]
    ]
    type = "UserAssigned"
  }

  parameters = {
    "$connections" = jsonencode(
      {
        azureblob = {
          connectionId   = "/subscriptions/${var.AZ_SUBSCRIPTION_ID}/resourceGroups/${each.value["rg_name"]}/providers/Microsoft.Web/connections/${data.azurerm_managed_api.azureblob.name}"
          connectionName = data.azurerm_managed_api.azureblob.name
          connectionProperties = {
            authentication = {
              identity = each.value["managedidentity_id"]
              type     = "ManagedServiceIdentity"
            }
          }
          id = data.azurerm_managed_api.azureblob.id
        }
        azuremonitorlogs = {
          connectionId   = "/subscriptions/${var.AZ_SUBSCRIPTION_ID}/resourceGroups/${each.value["rg_name"]}/providers/Microsoft.Web/connections/${data.azurerm_managed_api.azuremonitorlogs.name}"
          connectionName = data.azurerm_managed_api.azuremonitorlogs.name
          connectionProperties = {
            authentication = {
              identity = each.value["managedidentity_id"]
              type     = "ManagedServiceIdentity"
            }
          }
          id = data.azurerm_managed_api.azuremonitorlogs.id
        }
      }
    )

  }
  workflow_parameters = {
    "$connections" = jsonencode(
      {
        defaultValue = {}
        type         = "Object"
      }
    )
  }
}

resource "azurerm_logic_app_trigger_recurrence" "recurrence" {
  for_each     = local.azurerm_logic_app_workflow_identites
  name         = "Recurrence"
  logic_app_id = azurerm_logic_app_workflow.logic_app_workflow[each.key].id
  frequency    = "Hour"
  interval     = 1
}

resource "azurerm_logic_app_action_custom" "query" {
  for_each     = local.azurerm_logic_app_workflow_identites
  name         = "Run_query_and_list_results"
  logic_app_id = azurerm_logic_app_workflow.logic_app_workflow[each.key].id

  body = jsonencode(
    {

      inputs = {
        body = "let dt = now();\nlet year = datetime_part('year', dt);\nlet month = datetime_part('month', dt);\nlet day = datetime_part('day', dt);\nlet hour = datetime_part('hour', dt);\nlet startTime = make_datetime(year,month,day,hour,0)-1h;\nlet endTime = startTime + 1h - 1tick;\nAzureDiagnostics\n| where ingestion_time() between(startTime .. endTime)\n| project\n    TenantId,\n    TimeGenerated,\n    ResourceId,\n    Category,\n    ResourceGroup,\n    SubscriptionId,\n    ResourceProvider,\n    Resource,\n    ResourceType,\n    OperationName,\n    SourceSystem,\n    stream_s,\n    pod_s,\n    collectedBy_s,\n    log_s,\n    containerID_s,\n    Type,\n    _ResourceId",
        host = {
          connection = {
            name = "@parameters('$connections')['azuremonitorlogs']['connectionId']"
          }
        },
        method = "post",
        path   = "/queryData",
        queries = {
          resourcegroups = each.value["rg_name"],
          resourcename   = each.value["loganalytics"],
          resourcetype   = "Log Analytics Workspace",
          subscriptions  = var.AZ_SUBSCRIPTION_ID,
          timerange      = "Last hour"
        }
      },
      runAfter = {},
      type     = "ApiConnection"

    }
  )
}

resource "azurerm_logic_app_action_custom" "parse_json" {
  for_each     = local.azurerm_logic_app_workflow_identites
  name         = "Parse_JSON"
  logic_app_id = azurerm_logic_app_workflow.logic_app_workflow[each.key].id

  body = jsonencode(
    {

      inputs = {
        content = "@body('Run_query_and_list_results')",
        schema  = {}
      },
      runAfter = {
        "Run_query_and_list_results" = [
          "Succeeded"
        ]
      },
      type = "ParseJson"

    }
  )
}

resource "azurerm_logic_app_action_custom" "compose" {
  for_each     = local.azurerm_logic_app_workflow_identites
  name         = "Compose"
  logic_app_id = azurerm_logic_app_workflow.logic_app_workflow[each.key].id

  body = jsonencode(
    {

      inputs = {
        content = "@body('Parse_JSON')",
        schema  = {}
      },
      runAfter = {
        "Parse_JSON" = [
          "Succeeded"
        ]
      },
      type = "ParseJson"

    }
  )
}

resource "azurerm_logic_app_action_custom" "create_blob" {
  for_each     = local.azurerm_logic_app_workflow_identites
  name         = "Create_blob_(V2)"
  logic_app_id = azurerm_logic_app_workflow.logic_app_workflow[each.key].id

  body = jsonencode(
    {

      inputs = {
        body = "@outputs('Compose')",
        headers = {
          ReadFileMetadataFromServer = true
        },
        host = {
          connection = {
            name = "@parameters('$connections')['azureblob']['connectionId']"
          }
        },
        method = "post",
        path   = "/v2/datasets/@{encodeURIComponent(encodeURIComponent('${each.value["storageaccount"]}'))}/files",
        queries = {
          folderPath                   = "/archive-log-analytics-${each.value["folder"]}/@{formatDateTime(utcNow(), 'yyyy-MM-dd')}",
          name                         = "@{subtractFromTime(formatDateTime(utcNow(),'yyyy-MM-ddTHH:00:00'), 1,'Hour')}",
          queryParametersSingleEncoded = true
        }
      },
      runAfter = {
        "Compose" = [
          "Succeeded"
        ]
      },
      runtimeConfiguration = {
        contentTransfer = {
          transferMode = "Chunked"
        }
      },
      type = "ApiConnection"

    }
  )
}

