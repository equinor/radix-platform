data "azurerm_client_config" "current" {}

data "azuread_group" "this" {
  display_name     = "Radix Platform Operators"
  security_enabled = true
}

data "azurerm_role_definition" "this" {
  name = "Key Vault Secrets User"
}

data "azurerm_key_vault" "keyvault" {
  name                = "radix-keyv-${var.environment}" # template
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secret" "slack_webhook" {
  name         = "slack-webhook"
  key_vault_id = data.azurerm_key_vault.keyvault.id
}

resource "azurerm_key_vault" "this" {
  name                          = var.vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days    = var.testzone ? 7 : 90
  purge_protection_enabled      = var.testzone ? false : true
  enable_rbac_authorization     = var.enable_rbac_authorization
  public_network_access_enabled = false
  tags = {
    IaC = "terraform"
  }
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = []
  }


  sku_name = "standard"
}

resource "azurerm_role_assignment" "this" {
  count              = var.kv_secrets_user_id != "" ? 1 : 0
  scope              = azurerm_key_vault.this.id
  role_definition_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}${data.azurerm_role_definition.this.role_definition_id}"
  principal_id       = var.kv_secrets_user_id
}

data "azurerm_subnet" "subnet" {
  name                 = "private-links"
  virtual_network_name = "vnet-hub"
  resource_group_name  = var.vnet_resource_group
}

resource "azurerm_key_vault_access_policy" "this" {
  for_each     = var.enable_rbac_authorization == false ? { "${var.vault_name}" : true } : {}
  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_group.this.object_id
  certificate_permissions = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "ManageContacts", "ManageIssuers", "GetIssuers", "ListIssuers", "SetIssuers", "DeleteIssuers"
  ]
  key_permissions = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore"
  ]
  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"
  ]
}

resource "azurerm_private_endpoint" "this" {
  name                = "pe-${var.vault_name}"
  location            = var.location
  resource_group_name = var.vnet_resource_group
  subnet_id           = data.azurerm_subnet.subnet.id
  depends_on          = [azurerm_key_vault.this]

  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_key_vault.this.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
  tags = {
    IaC = "terraform"
  }
}
resource "azurerm_private_dns_a_record" "this" {
  name                = azurerm_key_vault.this.name
  zone_name           = "privatelink.vaultcore.azure.net"
  resource_group_name = var.vnet_resource_group
  ttl                 = 60
  records             = [azurerm_private_endpoint.this.private_service_connection.0.private_ip_address]
}

output "azurerm_key_vault_id" {
  value = azurerm_key_vault.this.id
}

##  Azure App Configuration

resource "azurerm_user_assigned_identity" "app_config" {
  name                = "radix-id-appconfig-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_app_configuration" "this" {
  name                                 = "radix-appconfig-${var.environment}"
  resource_group_name                  = var.resource_group_name
  location                             = var.location
  sku                                  = var.appconfig_sku
  local_auth_enabled                   = true
  public_network_access                = "Enabled"
  purge_protection_enabled             = var.appconfig_sku == "developer" ? false : true # This field only works for standard sku
  data_plane_proxy_authentication_mode = "Pass-through"
  # soft_delete_retention_days  = var.appconfig_sku == "developer" ? null : 7

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.app_config.id,
    ]
  }
}

######################################################################################
# Logic App to monitor Key Vault events and send notifications to Slack             #
######################################################################################

resource "azurerm_eventgrid_system_topic" "this" {
  name                   = "${var.vault_name}-topic"
  resource_group_name    = var.resource_group_name
  location               = var.location
  source_arm_resource_id = azurerm_key_vault.this.id
  topic_type             = "Microsoft.KeyVault.vaults"
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_logic_app_workflow" "this" {
  enabled  = true
  location = var.location
  name     = var.vault_name

  parameters = {
    "$connections" = jsonencode({
      azureeventgrid = {
        connectionId   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Web/connections/azureeventgrid"
        connectionName = "azureeventgrid"
        id             = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Web/locations/${var.location}/managedApis/azureeventgrid"
      }
    })
  }

  resource_group_name = var.resource_group_name
  tags = {
    IaC = "terraform"
  }

  workflow_parameters = {
    "$connections" = jsonencode({
      defaultValue = {}
      type         = "Object"
    })
    SlackWebhookUrl = jsonencode({
      defaultValue = nonsensitive(data.azurerm_key_vault_secret.slack_webhook.value)
      metadata = {
        description = "Slack webhook URL for notifications"
      }
      type = "String"
    })
  }

  workflow_schema  = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
  workflow_version = "1.0.0.0"
}

data "azurerm_managed_api" "this" {
  name     = "azureeventgrid"
  location = var.location
}

resource "azurerm_api_connection" "this" {
  display_name   = "azureeventgrid-${var.environment}"
  managed_api_id = data.azurerm_managed_api.this.id
  name           = "azureeventgrid"
  parameter_values = {
    "token:grantType" = "code"
    "token:tenantId"  = "${data.azurerm_client_config.current.tenant_id}"
  }
  resource_group_name = var.resource_group_name
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_logic_app_trigger_custom" "this" {
  name         = "When_a_resource_event_occurs"
  logic_app_id = azurerm_logic_app_workflow.this.id
  body = jsonencode(
    {
      inputs = {
        body = {
          properties = {
            destination = {
              endpointType = "webhook"
              properties = {
                endpointUrl = "@listCallbackUrl()"
              }
            }
            filter = {
              includedEventTypes = [
                "Microsoft.KeyVault.SecretExpired",
                "Microsoft.KeyVault.SecretNearExpiry",
                "Microsoft.KeyVault.SecretNewVersionCreated",
              ]
            }
            topic = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.KeyVault/vaults/${var.vault_name}"
          }
        }
        host = {
          connection = {
            name = "@parameters('$connections')['azureeventgrid']['connectionId']"
          }
        }
        path = "/subscriptions/@{encodeURIComponent('${data.azurerm_client_config.current.subscription_id}')}/providers/@{encodeURIComponent('Microsoft.KeyVault.vaults')}/resource/eventSubscriptions"
        queries = {
          x-ms-api-version = "2017-09-15-preview"
        }
      }

      type = "ApiConnectionWebhook"
    }
  )

}

resource "azurerm_logic_app_action_custom" "this" {
  body = jsonencode({
    actions = {
      Switch_EventType = {
        cases = {
          Expired = {
            actions = {
              Post_Expired = {
                inputs = {
                  body = {
                    text = ":warning: A *Key Vault secret has expired!*\n*Vault:* @{items('ForEach_Events')?['data']?['vaultName']}\n*Secret:* @{items('ForEach_Events')?['data']?['objectName']}"
                  }
                  headers = {
                    Content-Type = "application/json"
                  }
                  method = "POST"
                  uri    = "@parameters('SlackWebhookUrl')"
                }
                type = "Http"
              }
            }
            case = "Microsoft.KeyVault.SecretExpired"
          }
          NearExpiry = {
            actions = {
              Post_NearExpiry = {
                inputs = {
                  body = {
                    text = ":hourglass_flowing_sand: A *Key Vault secret is nearing expiry!*\n*Vault:* @{items('ForEach_Events')?['data']?['vaultName']}\n*Secret:* @{items('ForEach_Events')?['data']?['objectName']}"
                  }
                  headers = {
                    Content-Type = "application/json"
                  }
                  method = "POST"
                  uri    = "@parameters('SlackWebhookUrl')"
                }
                type = "Http"
              }
            }
            case = "Microsoft.KeyVault.SecretNearExpiry"
          }
          NewVersion = {
            actions = {
              Post_NewVersion = {
                inputs = {
                  body = {
                    text = ":lock: A *new Key Vault secret version* was created!\n*Vault:* @{items('ForEach_Events')?['data']?['vaultName']}\n*Secret:* @{items('ForEach_Events')?['data']?['objectName']}\n*Version:* @{items('ForEach_Events')?['data']?['version']}"
                  }
                  headers = {
                    Content-Type = "application/json"
                  }
                  method = "POST"
                  uri    = "@parameters('SlackWebhookUrl')"
                }
                type = "Http"
              }
            }
            case = "Microsoft.KeyVault.SecretNewVersionCreated"
          }
        }
        default = {
          actions = {
            Post_Unknown = {
              inputs = {
                body = {
                  text = ":grey_question: Received an *unhandled Key Vault event type*: @{items('ForEach_Events')?['eventType']}"
                }
                headers = {
                  Content-Type = "application/json"
                }
                method = "POST"
                uri    = "@parameters('SlackWebhookUrl')"
              }
              type = "Http"
            }
          }
        }
        expression = "@items('ForEach_Events')?['eventType']"
        type       = "Switch"
      }
    }
    foreach  = "@triggerBody()"
    runAfter = {}
    type     = "Foreach"
  })
  logic_app_id = azurerm_logic_app_workflow.this.id
  name         = "ForEach_Events"
}

output "azurerm_app_configuration_id" {
  value = azurerm_app_configuration.this.id
}
