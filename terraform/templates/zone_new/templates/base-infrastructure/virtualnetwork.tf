module "azurerm_virtual_network" {
  source              = "../../../modules/virtualnetwork"
  location            = module.config.location
  enviroment          = module.config.environment
  vnet_resource_group = module.resourcegroup_vnet.data.name
  private_dns_zones   = tolist(module.config.private_dns_zones_names)
  depends_on          = [module.resourcegroup_vnet]
  testzone            = module.config.zoneconfig.testzone

}

module "azurerm_public_ip_prefix_ingress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = module.resourcegroup_clusters.data.name
  publicipprefixname  = "ippre-ingress-radix-aks-${zone}-${location}-001" # template
  pipprefix           = "ingress-radix-aks"
  pippostfix          = "prod"
  enviroment          = module.config.environment
  prefix_length       = 29
  publicipcounter     = 8
  depends_on          = [module.resourcegroup_clusters]
  # zones               = ["1", "2", "3"]
  testzone = module.config.zoneconfig.testzone
}

module "azurerm_public_ip_prefix_egress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = module.resourcegroup_clusters.data.name
  publicipprefixname  = "ippre-radix-aks-${zone}-${location}-001" # template
  pipprefix           = "radix-aks"
  pippostfix          = module.config.location
  enviroment          = zone # template
  prefix_length       = 28
  publicipcounter     = 16
  depends_on          = [module.resourcegroup_clusters]
  testzone            = module.config.zoneconfig.testzone

}

output "egress_ips" {
  value = "${prefix}{module.azurerm_public_ip_prefix_egress.data.ip_prefix}" # template
}

output "public_ip_prefix_names" {
  value = {
    egress  = module.azurerm_public_ip_prefix_egress.data.name
    ingress = module.azurerm_public_ip_prefix_ingress.data.name
  }
}
