data "azurerm_storage_account" "terraform_state" {
  name                = "${module.config.subscription_shortname}radixinfra"
  resource_group_name = module.config.backend.resource_group_name
}

module "storageaccount" {
  source                    = "../../../modules/storageaccount"
  for_each                  = var.storageaccounts
  name                      = "radix${each.key}${module.config.environment}"
  tier                      = each.value.account_tier
  account_replication_type  = each.value.account_replication_type
  resource_group_name       = module.config.common_resource_group
  location                  = module.config.location
  environment               = module.config.environment
  kind                      = each.value.kind
  change_feed_enabled       = each.value.change_feed_enabled
  versioning_enabled        = each.value.versioning_enabled
  backup                    = each.value.backup
  subnet_id                 = module.azurerm_virtual_network.azurerm_subnet_id
  vnet_resource_group       = module.config.vnet_resource_group
  lifecyclepolicy           = each.value.lifecyclepolicy
  ip_rule                   = local.ip_rule
  log_analytics_id          = module.loganalytics.workspace_id
  shared_access_key_enabled = each.value.shared_access_key_enabled #Needed in module create container when running apply
}

