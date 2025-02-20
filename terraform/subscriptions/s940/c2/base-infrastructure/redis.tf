module "rediscache" {
  source              = "../../../modules/redis_cache"
  name                = "radix-${module.config.environment}"
  rg_name             = module.config.cluster_resource_group
  vnet_resource_group = module.config.vnet_resource_group
  sku_name            = "Standard"
  location            = module.config.location
}
