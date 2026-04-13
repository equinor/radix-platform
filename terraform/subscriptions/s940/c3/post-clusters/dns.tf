data "azurerm_public_ip" "gateway_pip" {
  for_each            = module.config.networksets
  name                = each.value.gatewayPIP
  resource_group_name = module.config.cluster_resource_group
}

locals {

  # Prepare cluster data for DNS module
  clusters_for_dns = {
    for cluster_name, cluster_config in module.config.cluster : cluster_name => {
      cluster_name      = cluster_name
      active_cluster    = lookup(cluster_config, "activecluster", false)
      nginx_ip          = module.config.networksets[cluster_config.networkset].ingressIP
      istio_ip          = data.azurerm_public_ip.gateway_pip[cluster_config.networkset].ip_address
      dns_wildcard_type = lookup(cluster_config, "dns_wildcard", "nginx")
    }
  }
}

module "dns_config" {
  source                = "../../../modules/aks/dns_config"
  clusters              = local.clusters_for_dns
  environment           = module.config.environment
  common_resource_group = module.config.common_resource_group
  zone_name             = module.config.environment == "platform" || module.config.environment == "extmon" ? "radix.equinor.com" : "${module.config.environment}.radix.equinor.com"
  dns_resource_group    = module.config.common_resource_group == "common-extmon" ? "common-platform" : module.config.common_resource_group
  create_active_records = module.config.environment != "extmon"
  create_extmon_record  = module.config.environment == "extmon"
}
