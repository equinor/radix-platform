module "resourcegroups" {
  for_each = toset(["common", "Logs-Dev", "monitoring"])

  source   = "../../../modules/resourcegroups"
  name     = each.value
  location = module.config.location
}

data "azurerm_subscription" "main" {
  subscription_id = module.config.subscription
}


module "backupvault" {
  source                = "../../../modules/backupvaults"
  name                  = "Backupvault-${module.config.environment}"
  resource_group_name   = "common"
  location              = module.config.location
  policyblobstoragename = "Backuppolicy-blob"
}


module "storageaccount" {
  source                   = "../../../modules/storageaccount_global"
  name                     = "s941radixinfra"
  tier                     = "Standard"
  account_replication_type = "RAGRS"
  resource_group_name      = "s941-tfstate"
  location                 = module.config.location
  environment              = module.config.environment
  kind                     = "StorageV2"
  change_feed_enabled      = false
  versioning_enabled       = false
  backup                   = true
  principal_id             = module.backupvault.data.backupvault.identity[0].principal_id
  vault_id                 = module.backupvault.data.backupvault.id
  policyblobstorage_id     = module.backupvault.data.policyblobstorage.id
  log_analytics_id         = module.config.backend.log_analytics_workspace_id
  
}

resource "azurerm_role_definition" "privatelink_role" {
  name        = "Radix Privatelink rbac-${module.config.environment}"
  scope       = "/subscriptions/${module.config.subscription}"
  description = "The role to manage Private Endpoints"

  permissions {
    actions = [
      "Microsoft.Resources/deployments/*",
      "Microsoft.Resources/subscriptions/resourceGroups/read",

      "Microsoft.Network/privateEndpoints/read",
      "Microsoft.Network/privateEndpoints/write",
      "Microsoft.Network/privateEndpoints/delete",
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/write",
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      // Persmissions to create Private DNS Zone entry:
      "Microsoft.Network/privateDnsZones/join/action",
      "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write",
      "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/read",
      "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/delete",
    ]
  }
  assignable_scopes = [
    data.azurerm_subscription.main.id
  ]
}

# resource "azurerm_monitor_action_group" "this" {
#   name                = "notify-radix-team-test"
#   resource_group_name = "common"
#   short_name          = "notify-radix"

#   email_receiver {
#     name                    = "radix-email-notification_-EmailAction-"
#     email_address           = "Radix@StatoilSRM.onmicrosoft.com"
#     use_common_alert_schema = false
#   }
# }

# resource "azurerm_monitor_activity_log_alert" "this" {
#   name                = "azure-service-health-radix-test"
#   resource_group_name = "common"
#   location            = module.config.location
#   scopes              = ["/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b"]
#   description         = "This alert will monitor a specific storage account updates."

#   criteria {
#     category = "ServiceHealth"

#     resource_id    = module.storageaccount.id
#     operation_name = "Microsoft.Storage/storageAccounts/write"
#     # category       = "Recommendation"
#   }

#   action {
#     action_group_id = azurerm_monitor_action_group.this.id

#     webhook_properties = {}
#   }
# }
