
module "nsg_rules" {
  source                   = "../../../modules/aks/nsg_rule"
  nsg_ids                  = module.clusters.nsg
  resource_group_name      = module.config.cluster_resource_group
  public_ip_resource_group = coalesce(module.config.public_ip_resource_group, "clusters-${module.config.environment}")
  clusters                 = module.config.cluster
  networksets              = module.config.networksets
}