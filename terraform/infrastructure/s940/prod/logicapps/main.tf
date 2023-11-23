terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  subscription_id = var.AZ_SUBSCRIPTION_ID

  features {}
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
  for_each            = var.logic_app_workflow
  name                = each.value["name"]
  location            = each.value["location"]
  resource_group_name = each.value["rg_name"]
  enabled             = true
  identity {
    identity_ids = [
      data.azurerm_user_assigned_identity.managed_identity[each.value["managed_identity_name"]].id
    ]
    type = "UserAssigned"
  }

  parameters = {
    "$connections" = jsonencode(
      {
        azureblob = {
          connectionId         = "/subscriptions/${var.AZ_SUBSCRIPTION_ID}/resourceGroups/${each.value["rg_name"]}/providers/Microsoft.Web/connections/${data.azurerm_managed_api.azureblob.name}"
          connectionName       = data.azurerm_managed_api.azureblob.name
          connectionProperties = {
            authentication = {
              identity = data.azurerm_user_assigned_identity.managed_identity[each.value["managed_identity_name"]].id
              type     = "ManagedServiceIdentity"
            }
          }
          id = data.azurerm_managed_api.azureblob.id
        }
        azuremonitorlogs = {
          connectionId         = "/subscriptions/${var.AZ_SUBSCRIPTION_ID}/resourceGroups/${each.value["rg_name"]}/providers/Microsoft.Web/connections/${data.azurerm_managed_api.azuremonitorlogs.name}"
          connectionName       = data.azurerm_managed_api.azuremonitorlogs.name
          connectionProperties = {
            authentication = {
              identity = data.azurerm_user_assigned_identity.managed_identity[each.value["managed_identity_name"]].id
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
  for_each     = var.logic_app_workflow
  name         = "Recurrence"
  logic_app_id = azurerm_logic_app_workflow.logic_app_workflow[each.key].id
  frequency    = "Hour"
  interval     = 1
  depends_on   = [data.azurerm_user_assigned_identity.managed_identity]
}

resource "azurerm_logic_app_action_custom" "query" {
  for_each     = var.logic_app_workflow
  name         = "Run_query_and_list_results"
  logic_app_id = azurerm_logic_app_workflow.logic_app_workflow[each.key].id
  depends_on   = [azurerm_logic_app_trigger_recurrence.recurrence]

  body = jsonencode(
    {
      inputs = {
        body = "let dt = now();\nlet year = datetime_part('year', dt);\nlet month = datetime_part('month', dt);\nlet day = datetime_part('day', dt);\nlet hour = datetime_part('hour', dt);\nlet startTime = make_datetime(year,month,day,hour,0)-1h;\nlet endTime = startTime + 1h - 1tick;\nAzureDiagnostics\n| where ingestion_time() between(startTime .. endTime)\n| project\n    TenantId,\n    TimeGenerated,\n    ResourceId,\n    Category,\n    ResourceGroup,\n    SubscriptionId,\n    ResourceProvider,\n    Resource,\n    ResourceType,\n    OperationName,\n    SourceSystem,\n    stream_s,\n    pod_s,\n    collectedBy_s,\n    log_s,\n    containerID_s,\n    Type,\n    _ResourceId",
        host = {
          connection = {
            name = "@parameters('$connections')['azuremonitorlogs']['connectionId']"
          }
        },
        method  = "post",
        path    = "/queryData",
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
  for_each     = var.logic_app_workflow
  name         = "Parse_JSON"
  logic_app_id = azurerm_logic_app_workflow.logic_app_workflow[each.key].id
  depends_on   = [azurerm_logic_app_action_custom.query]

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
  for_each     = var.logic_app_workflow
  name         = "Compose"
  logic_app_id = azurerm_logic_app_workflow.logic_app_workflow[each.key].id
  depends_on   = [azurerm_logic_app_action_custom.parse_json]

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
  for_each     = var.logic_app_workflow
  name         = "Create_blob_(V2)"
  logic_app_id = azurerm_logic_app_workflow.logic_app_workflow[each.key].id
  depends_on   = [azurerm_logic_app_action_custom.compose]

  body = jsonencode(
    {

      inputs = {
        body    = "@outputs('Compose')",
        headers = {
          ReadFileMetadataFromServer = true
        },
        host = {
          connection = {
            name = "@parameters('$connections')['azureblob']['connectionId']"
          }
        },
        method  = "post",
        path    = "/v2/datasets/@{encodeURIComponent(encodeURIComponent('${each.value["storageaccount"]}'))}/files",
        queries = {
          folderPath                   = "/archive-log-analytics-${each.value["folder"]}/@{formatDateTime(utcNow(), 'yyyy')}/@{formatDateTime(utcNow(), 'MM')}/@{formatDateTime(utcNow(), 'dd')}",
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

