module "resourcegroups" {
  for_each = toset(var.resource_groups)
  source   = "../../../modules/resourcegroups"
  name     = "${local.external_outputs.global.data.subscription_shortname}-${each.value}"
  location = local.outputs.location
}

module "loganalytics" {
  source                        = "../../../modules/log-analytics"
  workspace_name                = "${local.external_outputs.global.data.subscription_shortname}-diagnostics-${local.outputs.enviroment_L}"
  resource_group_name           = "${local.external_outputs.global.data.subscription_shortname}-${local.outputs.enviroment_L}"
  location                      = local.outputs.location
  retention_in_days             = 30
  local_authentication_disabled = false
}

module "backupvault" {
  source                = "../../../modules/backupvaults"
  name                  = "${local.external_outputs.global.data.subscription_shortname}-backupvault-${local.outputs.enviroment_L}"
  resource_group_name   = "${local.external_outputs.global.data.subscription_shortname}-${local.outputs.enviroment_L}"
  location              = local.outputs.location
  policyblobstoragename = "${local.external_outputs.global.data.subscription_shortname}-backuppolicy-blob-${local.outputs.enviroment_L}"
  depends_on            = [module.resourcegroups]
}

module "storageaccount" {
  source                   = "../../../modules/storageaccount"
  for_each                 = var.storageaccounts
  name                     = "${local.external_outputs.global.data.subscription_shortname}${each.key}${local.outputs.enviroment_L}"
  tier                     = each.value.account_tier
  account_replication_type = each.value.account_replication_type
  resource_group_name      = each.value.resource_group_name
  location                 = each.value.location
  environment              = local.outputs.enviroment_L
  kind                     = each.value.kind
  change_feed_enabled      = each.value.change_feed_enabled
  versioning_enabled       = each.value.versioning_enabled
  roleassignment           = each.value.roleassignment
  principal_id             = module.backupvault.data.backupvault.identity[0].principal_id
  vault_id                 = module.backupvault.data.backupvault.id
  policyblobstorage_id     = module.backupvault.data.policyblobstorage.id
}
