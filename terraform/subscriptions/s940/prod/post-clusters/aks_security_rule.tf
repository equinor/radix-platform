
locals {
  nsg_resource_group_names = {
    for cluster_name, cluster_config in module.config.cluster :
    "nsg-${cluster_name}" => lookup(cluster_config, "cluster_resource_group", module.config.cluster_resource_group)
  }
}

module "nsg_rules" {
  source                   = "../../../modules/aks/nsg_rule"
  nsg_ids                  = merge(module.clusters.nsg, try(module.clusters_c1.nsg, {}))
  nsg_resource_group_names = local.nsg_resource_group_names
  resource_group_name      = module.config.cluster_resource_group
  public_ip_resource_group = coalesce(module.config.public_ip_resource_group, "clusters-${module.config.environment}")
  clusters                 = module.config.cluster
  networksets              = module.config.networksets
}