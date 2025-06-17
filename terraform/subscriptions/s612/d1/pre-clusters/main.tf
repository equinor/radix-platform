module "config" {
  source = "../../../modules/config"
}

module "radix_pre_cluster" {
  source                  = "../../../modules/radix_pre"
  for_each                = module.config.cluster
  address_space           = module.config.networksets[each.value.networkset].vnet
  aks_version             = each.value.aksversion
  cluster_name            = each.key
  cluster_resource_group  = module.config.cluster_resource_group
  common_resource_group   = module.config.common_resource_group
  developers              = module.config.developers
  dns_prefix              = lookup(module.config.cluster[each.key], "dns_prefix", "")
  environment             = module.config.environment
  ingressIP               = module.config.networksets[each.value.networkset].ingressIP
  location                = module.config.location
  network_policy          = each.value.network_policy
  outbound_ip_address_ids = module.config.networksets[each.value.networkset].egress
  private_dns_zones_names = module.config.private_dns_zones_names
  subscription            = module.config.subscription
  vnet_resource_group     = module.config.vnet_resource_group
  nodepools               = var.nodepools
  systempool              = var.systempool
}

