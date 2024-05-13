module "resourcegroups" {
  for_each = toset(["backups", "common", "Logs-Dev"])

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
  source                    = "../../../modules/storageaccount_global"
  name                      = "s941radixinfra"
  tier                      = "Standard"
  account_replication_type  = "RAGRS"
  resource_group_name       = "s941-tfstate"
  location                  = module.config.location
  environment               = module.config.environment
  kind                      = "StorageV2"
  change_feed_enabled       = false
  versioning_enabled        = false
  backup                    = true
  shared_access_key_enabled = true
  principal_id              = module.backupvault.data.backupvault.identity[0].principal_id
  vault_id                  = module.backupvault.data.backupvault.id
  policyblobstorage_id      = module.backupvault.data.policyblobstorage.id
}