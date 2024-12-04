module "rediscache" {
  source              = "../../../modules/redis_cache"
  name                = "redis-${module.config.environment}"
  rg_name             = module.config.cluster_resource_group
  vnet_resource_group = "cluster-vnet-hub-${module.config.environment}"
  sku_name            = "Basic"
}