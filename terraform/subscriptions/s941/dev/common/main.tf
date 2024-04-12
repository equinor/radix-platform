module "config" {
  source = "../../../modules/config"
}

module "resourcegroups_ver1" {
  for_each             = var.resource_groups_ver1
  source               = "../../../modules/resourcegroups_ver1"
  name                 = each.value.name
  location             = module.config.location
  roleassignment       = each.value.roleassignment
  principal_id         = module.mi.data.principal_id
  role_definition_name = each.value.role_definition_name
}

module "mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-infrastructure-${module.config.environment}"
  location            = module.config.location
  resource_group_name = "common-${module.config.environment}"

}

module "backupvault" {
  source                = "../../../modules/backupvaults"
  name                  = "Backupvault-${module.config.environment}"
  resource_group_name   = "common-${module.config.environment}"
  location              = module.config.location
  policyblobstoragename = "Backuppolicy-blob"
  depends_on            = [module.resourcegroups_ver1]
}

module "loganalytics" {
  source                        = "../../../modules/log-analytics"
  workspace_name                = "radix-logs-${module.config.environment}"
  resource_group_name           = "common-${module.config.environment}"
  location                      = module.config.location
  retention_in_days             = 30
  local_authentication_disabled = false
}

module "storageaccount" {
  source                   = "../../../modules/storageaccount"
  for_each                 = var.storageaccounts
  name                     = "radix${each.key}${module.config.environment}"
  tier                     = each.value.account_tier
  account_replication_type = each.value.account_replication_type
  resource_group_name      = each.value.resource_group_name
  location                 = each.value.location
  environment              = module.config.environment
  kind                     = each.value.kind
  change_feed_enabled      = each.value.change_feed_enabled
  versioning_enabled       = each.value.versioning_enabled
  backup                   = each.value.backup
  principal_id             = module.backupvault.data.backupvault.identity[0].principal_id
  vault_id                 = module.backupvault.data.backupvault.id
  policyblobstorage_id     = module.backupvault.data.policyblobstorage.id
  subnet_id                = local.external_outputs.virtualnetwork.data.vnet_subnet.id
  velero_service_principal = each.value.velero_service_principal
  vnet_resource_group      = module.config.vnet_resource_group
  lifecyclepolicy          = each.value.lifecyclepolicy
}

output "mi_id" {
  value = module.mi.data.id
}

output "workspace_id" {
  value = module.loganalytics.workspace_id
}

output "log_storageaccount_id" {
  value = module.storageaccount["log"].data.id
}
