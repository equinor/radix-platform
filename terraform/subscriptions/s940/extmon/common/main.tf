module "resourcegroups" {
  for_each = toset(var.resource_groups)
  source   = "../../../modules/resourcegroups"
  name     = each.value
  location = local.outputs.location
}

module "mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-infrastructure-${local.outputs.enviroment}"
  location            = local.outputs.location
  resource_group_name = "common-${local.outputs.enviroment}"

}

module "backupvault" {
  source                = "../../../modules/backupvaults"
  name                  = "Backupvault-${local.outputs.enviroment}"
  resource_group_name   = "common-${local.outputs.enviroment}"
  location              = local.outputs.location
  policyblobstoragename = "Backuppolicy-blob"
  depends_on            = [module.resourcegroups]
}

module "loganalytics" {
  source                        = "../../../modules/log-analytics"
  workspace_name                = "radix-logs-${local.outputs.enviroment}"
  resource_group_name           = "common-${local.outputs.enviroment}"
  location                      = local.outputs.location
  retention_in_days             = 30
  local_authentication_disabled = false
}


module "storageaccount" {
  source                   = "../../../modules/storageaccount"
  for_each                 = var.storageaccounts
  name                     = "radix${each.key}${local.outputs.enviroment}"
  tier                     = each.value.account_tier
  account_replication_type = each.value.account_replication_type
  resource_group_name      = each.value.resource_group_name
  location                 = each.value.location
  environment              = local.outputs.enviroment
  kind                     = each.value.kind
  change_feed_enabled      = each.value.change_feed_enabled
  versioning_enabled       = each.value.versioning_enabled
  backup                   = each.value.backup
  principal_id             = module.backupvault.data.backupvault.identity[0].principal_id
  vault_id                 = module.backupvault.data.backupvault.id
  policyblobstorage_id     = module.backupvault.data.policyblobstorage.id
  subnet_id                = local.external_outputs.virtualnetwork.data.vnet_subnet.id
  vnethub_resource_group   = local.external_outputs.virtualnetwork.data.vnet_hub.resource_group_name
  priv_endpoint            = each.value.private_endpoint
  firewall                 = each.value.firewall
}