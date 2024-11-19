data "azurerm_key_vault" "this" {
  name                = module.config.key_vault_name
  resource_group_name = module.config.common_resource_group
}

data "azurerm_key_vault_secret" "this" {
  name         = "radix-clusters"
  key_vault_id = data.azurerm_key_vault.this.id
}

data "azurerm_storage_account" "this" {
  name                = "radixlog${module.config.environment}"
  resource_group_name = module.config.common_resource_group
}

# module "clusternetwork" {
#   source              = "../../../modules/cluster_network"
#   for_each            = { for k, v in jsondecode(nonsensitive(data.azurerm_key_vault_secret.this.value)).clusters : v.name => v.ip }
#   cluster_name        = each.key
#   resource_group_name = module.config.cluster_resource_group
#   location            = module.config.location
#   storageaccount_id   = data.azurerm_storage_account.this.id
#   address_space       = each.value
#   enviroment          = module.config.environment
# }

# locals {
#   flattened_vnets = {
#     for key, value in module.clusternetwork : key => {
#       cluster     = key
#       vnet_name   = value.vnet.name
#       vnet_id     = value.vnet.id
#       subnet_id   = tolist(value.vnet.subnet)[0].id
#       subnet_name = tolist(value.vnet.subnet)[0].name
#     }
#   }
# }

# output "vnets" {
#   value = local.flattened_vnets
# }