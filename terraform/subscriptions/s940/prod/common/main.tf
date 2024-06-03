module "config" {
  source = "../../../modules/config"
}

module "resourcegroups" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.common_resource_group
  location = module.config.location
}

data "azurerm_data_protection_backup_vault" "this" {
  name                = "Backupvault-${module.config.subscription_shortname}"
  resource_group_name = "common"
}

module "loganalytics" {
  source                        = "../../../modules/log-analytics"
  workspace_name                = "radix-logs-${module.config.environment}"
  resource_group_name           = "common-${module.config.environment}"
  location                      = module.config.location
  retention_in_days             = 30
  local_authentication_disabled = false
  #TODO: No setting for 100 GB/day Commitment Tier. Done manually
}


data "azurerm_virtual_network" "this" {
  name                = "vnet-hub"
  resource_group_name = "cluster-vnet-hub-prod"
}

data "azurerm_key_vault_secret" "this" {
  name         = "storageaccounts-ip-rule"
  key_vault_id = module.config.backend.ip_key_vault_id
}

data "azurerm_subnet" "this" {
  name                 = "private-links"
  resource_group_name  = module.config.vnet_resource_group
  virtual_network_name = data.azurerm_virtual_network.this.name
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
  subnet_id                = data.azurerm_subnet.this.id
  vnet_resource_group      = module.config.vnet_resource_group
  lifecyclepolicy          = each.value.lifecyclepolicy
  ip_rule                  = data.azurerm_key_vault_secret.this.value
  log_analytics_id         = module.loganalytics.workspace_id
}

module "acr" {
  source              = "../../../modules/acr"
  ip_rule             = data.azurerm_key_vault_secret.this.value
  location            = module.config.location
  resource_group_name = "common" #TODO
  acr                 = "prod"   #TODO
  vnet_resource_group = module.config.vnet_resource_group
  subnet_id           = data.azurerm_subnet.this.id
}

output "workspace_id" {
  value = module.loganalytics.workspace_id
}

output "log_storageaccount_id" {
  value = module.storageaccount["log"].data.id
}

