module "rediscache" {
  source              = "../../../modules/redis_cache"
  for_each            = var.aksclusters
  rg_name             = module.config.cluster_resource_group
  name                = each.key
  vnet_resource_group = "cluster-vnet-hub-${module.config.environment}"
}