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
  zone_name             = "radix.equinor.com"
  dns_resource_group    = "common-platform"
  create_active_records = false
}

resource "azurerm_dns_a_record" "extmon" {
  for_each            = anytrue([for c in local.clusters_for_dns : c.active_cluster]) ? { "extmon" : true } : {}
  name                = "*.ext-mon"
  zone_name           = "radix.equinor.com"
  resource_group_name = "common-platform"
  ttl                 = 30
  records = [{
    for k, v in local.clusters_for_dns :
    k => (v.dns_wildcard_type == "istio" ? v.istio_ip : v.nginx_ip) if v.active_cluster
  }[keys({ for k, v in local.clusters_for_dns : k => v if v.active_cluster })[0]]]


  lifecycle {
    create_before_destroy = false
  }
}

output "extmon_records" {
  description = "Extmon DNS records"
  value       = azurerm_dns_a_record.extmon
}

