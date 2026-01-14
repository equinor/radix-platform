locals {

  # Prepare cluster data for DNS module
  clusters_for_dns = {
    for cluster_name, cluster_config in module.config.cluster : cluster_name => {
      cluster_name      = cluster_name
      active_cluster    = lookup(cluster_config, "activecluster", false)
      nginx_ip          = module.config.networksets[cluster_config.networkset].ingressIP
      istio_ip          = module.config.networksets[cluster_config.networkset].istioIP
      dns_wildcard_type = lookup(cluster_config, "dns_wildcard", "nginx")
    }
  }
}

module "dns_config" {
  source                = "../../../modules/aks/dns_config"
  clusters              = local.clusters_for_dns
  environment           = module.config.environment
  common_resource_group = module.config.common_resource_group
}
