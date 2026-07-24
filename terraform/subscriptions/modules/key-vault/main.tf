################################################################################
# Data Sources
################################################################################

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "common" {
  name = var.resource_group_name
}

data "azuread_group" "this" {
  display_name     = var.subscription_contributor
  security_enabled = true
}

data "azurerm_role_definition" "this" {
  name  = "Key Vault Secrets User"
  scope = data.azurerm_subscription.current.id
}

data "azurerm_role_definition" "eventgrid_contributor" {
  name  = "EventGrid Contributor"
  scope = data.azurerm_subscription.current.id
}

data "azurerm_key_vault_secret" "slack_webhook" {
  name         = "slack-webhook"
  key_vault_id = azurerm_key_vault.config.id
}

data "azurerm_subnet" "subnet" {
  name                 = "private-links"
  virtual_network_name = "vnet-hub"
  resource_group_name  = var.vnet_resource_group
}

################################################################################
# Key Vault Resources
################################################################################

resource "azurerm_key_vault" "this" {
  name                          = var.vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days    = var.testzone ? 7 : 90
  purge_protection_enabled      = var.testzone ? false : true
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
  role_definition_id = data.azurerm_role_definition.this.id
  principal_id       = var.kv_secrets_user_id
}

resource "azurerm_role_assignment" "logic_app_managed_identity" {
  scope              = azurerm_key_vault.this.id
  role_definition_id = data.azurerm_role_definition.this.id
  principal_id       = var.logic_app_managed_identity.principal_id
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

################################################################################
# Config Key Vault for Bootstrap
################################################################################

resource "azurerm_key_vault" "config" {
  name                          = "radix-config-${var.environment}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  public_network_access_enabled = false
  soft_delete_retention_days    = 30
  purge_protection_enabled      = true
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

output "config_keyvault_name" {
  value = azurerm_key_vault.config.name
}

################################################################################
# Event Grid System Topic
################################################################################

resource "azurerm_eventgrid_system_topic" "this" {
  name                   = "${var.vault_name}-topic"
  resource_group_name    = var.resource_group_name
  location               = var.location
  source_resource_id     = azurerm_key_vault.this.id
  topic_type             = "Microsoft.KeyVault.vaults"
  tags = {
    IaC = "terraform"
  }
}

################################################################################
# Logic App Workflow
################################################################################

resource "azurerm_logic_app_workflow" "this" {
  name                = var.vault_name
  location            = var.location
  resource_group_name = var.resource_group_name

  workflow_parameters = {
    SlackWebhookUrl = jsonencode({
      defaultValue = nonsensitive(data.azurerm_key_vault_secret.slack_webhook.value)
      metadata = {
        description = "Slack webhook URL for notifications"
      }
      type = "String"
    })
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.logic_app_managed_identity.id]
  }

  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_logic_app_trigger_http_request" "this" {
  name         = "When_a_webhook_request_is_received"
  logic_app_id = azurerm_logic_app_workflow.this.id
  schema = jsonencode({
    type = "array"
    items = {
      type = "object"
      properties = {
        id = {
          type = "string"
        }
        eventType = {
          type = "string"
        }
        eventTime = {
          type = "string"
        }
        data = {
          type = "object"
          properties = {
            vaultName = {
              type = "string"
            }
            objectName = {
              type = "string"
            }
            version = {
              type = "string"
            }
          }
        }
      }
    }
  })
}

resource "azurerm_logic_app_action_custom" "send_slack" {
  name         = "Send_Slack_Notification"
  logic_app_id = azurerm_logic_app_workflow.this.id
  body = jsonencode({
    type    = "Foreach"
    foreach = "@triggerBody()"
    actions = {
      Switch_EventType = {
        type       = "Switch"
        expression = "@item()?['eventType']"
        cases = {
          Expired = {
            case = "Microsoft.KeyVault.SecretExpired"
            actions = {
              Post_Expired = {
                type = "Http"
                inputs = {
                  method = "POST"
                  uri    = "@parameters('SlackWebhookUrl')"
                  headers = {
                    Content-Type = "application/json"
                  }
                  body = {
                    text = ":warning: A *Key Vault secret has expired!*\n*Vault:* @{item()?['data']?['vaultName']}\n*Secret:* @{item()?['data']?['objectName']}"
                  }
                }
              }
            }
          }
          NearExpiry = {
            case = "Microsoft.KeyVault.SecretNearExpiry"
            actions = {
              Post_NearExpiry = {
                type = "Http"
                inputs = {
                  method = "POST"
                  uri    = "@parameters('SlackWebhookUrl')"
                  headers = {
                    Content-Type = "application/json"
                  }
                  body = {
                    text = ":hourglass_flowing_sand: A *Key Vault secret is nearing expiry!*\n*Vault:* @{item()?['data']?['vaultName']}\n*Secret:* @{item()?['data']?['objectName']}"
                  }
                }
              }
            }
          }
          NewVersion = {
            case = "Microsoft.KeyVault.SecretNewVersionCreated"
            actions = {
              Post_NewVersion = {
                type = "Http"
                inputs = {
                  method = "POST"
                  uri    = "@parameters('SlackWebhookUrl')"
                  headers = {
                    Content-Type = "application/json"
                  }
                  body = {
                    text = ":lock: A *new Key Vault secret version* was created!\n*Vault:* @{item()?['data']?['vaultName']}\n*Secret:* @{item()?['data']?['objectName']}\n*Version:* @{item()?['data']?['version']}"
                  }
                }
              }
            }
          }
        }
        default = {
          actions = {
            Post_Unknown = {
              type = "Http"
              inputs = {
                method = "POST"
                uri    = "@parameters('SlackWebhookUrl')"
                headers = {
                  Content-Type = "application/json"
                }
                body = {
                  text = ":grey_question: Received an *unhandled Key Vault event type*: @{item()?['eventType']}"
                }
              }
            }
          }
        }
        runAfter = {}
      }
    }
    runAfter = {}
  })
}

################################################################################
# Event Grid Subscription and Role Assignment
################################################################################

resource "azurerm_role_assignment" "logic_app_eventgrid" {
  scope              = data.azurerm_resource_group.common.id
  role_definition_id = data.azurerm_role_definition.eventgrid_contributor.id
  principal_id       = var.logic_app_managed_identity.principal_id
}

resource "azurerm_eventgrid_system_topic_event_subscription" "logic_app" {
  name                = "${var.vault_name}-logicapp-subscription"
  system_topic        = azurerm_eventgrid_system_topic.this.name
  resource_group_name = var.resource_group_name

  included_event_types = [
    "Microsoft.KeyVault.SecretNearExpiry", # Fires 30 days before expiry
    "Microsoft.KeyVault.SecretExpired",
    "Microsoft.KeyVault.SecretNewVersionCreated",
  ]

  webhook_endpoint {
    url                             = azurerm_logic_app_trigger_http_request.this.callback_url
    max_events_per_batch            = 1
    preferred_batch_size_in_kilobytes = 64
  }
}
