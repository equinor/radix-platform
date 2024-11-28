module "rediscache" {
  source              = "../../../modules/redis_cache"
  for_each            = { for k, v in var.aksclusters : k => v }
  rg_name             = "clusters"
  name                = each.key
  vnet_resource_group = "cluster-vnet-hub-prod" #TODO ${module.config.environment}"
}