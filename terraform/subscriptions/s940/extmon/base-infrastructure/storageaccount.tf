data "azurerm_storage_account" "terraform_state" {
  name                = "${module.config.subscription_shortname}radixinfra"
  resource_group_name = module.config.backend.resource_group_name
}
data "azurerm_data_protection_backup_vault" "this" {
  name                = "Backupvault-${module.config.subscription_shortname}"
  resource_group_name = "common"
}

module "storageaccount" {
  source                   = "../../../modules/storageaccount"
  for_each                 = var.storageaccounts
  name                     = "radix${each.key}${module.config.environment}"
  tier                     = each.value.account_tier
  account_replication_type = each.value.account_replication_type
  resource_group_name      = module.config.common_resource_group
  location                 = module.config.location
  environment              = module.config.environment
  kind                     = each.value.kind
  change_feed_enabled      = each.value.change_feed_enabled
  versioning_enabled       = each.value.versioning_enabled
  backup                   = each.value.backup
  principal_id             = data.azurerm_data_protection_backup_vault.this.identity[0].principal_id
  vault_id                 = data.azurerm_data_protection_backup_vault.this.id
  policyblobstorage_id     = "${data.azurerm_data_protection_backup_vault.this.id}/backupPolicies/Backuppolicy-blob"
  subnet_id                = module.azurerm_virtual_network.azurerm_subnet_id
  vnet_resource_group      = module.config.vnet_resource_group
  lifecyclepolicy          = each.value.lifecyclepolicy
  log_analytics_id         = module.loganalytics.workspace_id
}

output "velero_storage_account" {
  value = module.storageaccount.velero.data.name
}

