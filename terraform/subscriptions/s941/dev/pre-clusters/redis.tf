module "rediscache" {
  source              = "../../../modules/redis_cache"
  for_each            = module.config.cluster
  rg_name             = module.config.cluster_resource_group
  name                = each.key
  vnet_resource_group = "cluster-vnet-hub-${module.config.environment}"
  sku_name            = "Basic"
}