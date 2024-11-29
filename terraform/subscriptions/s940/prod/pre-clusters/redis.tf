module "rediscache" {
  source              = "../../../modules/redis_cache"
  for_each            = module.config.cluster
  rg_name             = "clusters"
  name                = each.key
  vnet_resource_group = "cluster-vnet-hub-prod" #TODO ${module.config.environment}"
}