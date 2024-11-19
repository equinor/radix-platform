module "rediscache" {
  source              = "../../../modules/redis_cache"
  for_each            = { for k in jsondecode(nonsensitive(data.azurerm_key_vault_secret.this.value)).clusters : k.name => k }
  rg_name             = module.config.cluster_resource_group
  name                = each.key
  vnet_resource_group = "cluster-vnet-hub-${module.config.environment}"
  location            = module.config.location
}