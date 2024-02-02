# module "resourcegroups" {
#   for_each = toset(var.resource_groups)
#   source   = "../../../modules/resourcegroups"
#   name     = each.value
#   location = local.outputs.location
# }

module "resourcegroups_ver1" {
  for_each             = var.resource_groups_ver1
  source               = "../../../modules/resourcegroups_ver1"
  name                 = each.value.name
  location             = local.outputs.location
  roleassignment       = each.value.roleassignment
  principal_id         = module.mi.data.principal_id
  role_definition_name = each.value.role_definition_name
  # policyassignment     = each.value.policyassignment
  # policy_name          = each.value.policy_name
  # policy_definition_id = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/providers/Microsoft.Authorization/policyDefinitions/Radix-Enforce-Diagnostics-AKS-Clusters"

}

module "mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "id-radix-infrastructure-${local.outputs.enviroment}"
  location            = local.outputs.location
  resource_group_name = "common-${local.outputs.enviroment}"

}

# module "policyassignment_resourcegroup" {
#   source = "../../../modules/policyassignment_resourcegroup"
#   name = "Radix-Enforce-Diagnostics-AKS-Clusters"
#   resource_group_id =  "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common-dev"
#   policy_definition_id = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/providers/Microsoft.Authorization/policyDefinitions/Radix-Enforce-Diagnostics-AKS-Clusters"
#   # identity  = ["/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common-dev/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-radix-infrastructure-dev"]
# }

module "backupvault" {
  source                = "../../../modules/backupvaults"
  name                  = "Backupvault-${local.outputs.enviroment}"
  resource_group_name   = "common-${local.outputs.enviroment}"
  location              = local.outputs.location
  policyblobstoragename = "Backuppolicy-blob"
  depends_on            = [module.resourcegroups_ver1]
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
  environment              = local.outputs.enviroment_L
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

