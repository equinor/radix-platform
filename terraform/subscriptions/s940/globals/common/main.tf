module "resourcegroups" {
  for_each = toset(["common", "monitoring"])

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
  name                     = "s940radixinfra"
  tier                     = "Standard"
  account_replication_type = "RAGRS"
  resource_group_name      = "s940-tfstate"
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

output "environment" {
  value = module.config.environment
}

