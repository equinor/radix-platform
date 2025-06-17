data "azurerm_storage_account" "terraform_state" {
  name                = "${var.subscription_shortname}radixinfra"
  resource_group_name = "${var.subscription_shortname}-tfstate"
}

module "storageaccount" {
  source                   = "../../modules/storageaccount"
  for_each                 = var.storageaccounts
  name                     = "radix${each.key}${var.environment}"
  tier                     = each.value.account_tier
  account_replication_type = each.value.account_replication_type
  resource_group_name      = each.value.resource_group_name
  location                 = each.value.location
  environment              = var.environment
  kind                     = each.value.kind
  change_feed_enabled      = each.value.change_feed_enabled
  versioning_enabled       = each.value.versioning_enabled
  backup                   = each.value.backup
  principal_id             = module.backupvault.data.backupvault.identity[0].principal_id
  vault_id                 = module.backupvault.data.backupvault.id
  policyblobstorage_id     = module.backupvault.data.policyblobstorage.id
  subnet_id                = module.azurerm_virtual_network.azurerm_subnet_id
  vnet_resource_group      = var.vnet_resource_group
  lifecyclepolicy          = each.value.lifecyclepolicy
  log_analytics_id         = module.loganalytics.workspace_id
  subscription_shortname   = var.subscription_shortname
  cluster_type             = var.cluster_type
  depends_on               = [module.backupvault]
}

output "velero_storage_account" {
  value = module.storageaccount.velero.data.name
}


