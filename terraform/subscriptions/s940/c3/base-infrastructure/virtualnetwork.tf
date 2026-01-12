module "azurerm_virtual_network" {
  source              = "../../../modules/virtualnetwork"
  location            = module.config.location
  enviroment          = module.config.environment
  vnet_resource_group = module.resourcegroup_vnet.data.name
  private_dns_zones   = tolist(module.config.private_dns_zones_names)
  depends_on          = [module.resourcegroup_vnet]

}

module "azurerm_public_ip_prefix_ingress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = module.resourcegroup_clusters.data.name
  publicipprefixname  = "ippre-ingress-radix-aks-${module.config.environment}-${module.config.location}-001"
  pipprefix           = "ingress-radix-aks"
  pippostfix          = module.config.location
  enviroment          = module.config.environment
  prefix_length       = 29
  publicipcounter     = 8
  zones               = ["1", "2", "3"]
}

module "azurerm_public_ip_prefix_egress_001" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = module.resourcegroup_clusters.data.name
  publicipprefixname  = "ippre-radix-aks-${module.config.environment}-${module.config.location}-001"
  pipprefix           = "radix-aks"
  pippostfix          = module.config.location
  enviroment          = module.config.environment
  prefix_length       = 28 # Max aivailable /28
  publicipcounter     = 16
}

module "azurerm_public_ip_prefix_egress_002" {
  source               = "../../../modules/network_publicipprefix"
  location             = module.config.location
  resource_group_name  = module.resourcegroup_clusters.data.name
  publicipprefixname   = "ippre-radix-aks-${module.config.environment}-${module.config.location}-002"
  pipprefix            = "radix-aks"
  pippostfix           = module.config.location
  enviroment           = module.config.environment
  prefix_length        = 28 # Max aivailable /28
  publicipcounter      = 16
  puplicipstartcounter = 17
}

module "azurerm_public_ip_prefix_egress_003" {
  source               = "../../../modules/network_publicipprefix"
  location             = module.config.location
  resource_group_name  = module.resourcegroup_clusters.data.name
  publicipprefixname   = "ippre-radix-aks-${module.config.environment}-${module.config.location}-003"
  pipprefix            = "radix-aks"
  pippostfix           = module.config.location
  enviroment           = module.config.environment
  prefix_length        = 28 # Max aivailable /28
  publicipcounter      = 16
  puplicipstartcounter = 33
}

output "egress_ips" {
  value = "${module.azurerm_public_ip_prefix_egress_001.data.ip_prefix},${module.azurerm_public_ip_prefix_egress_002.data.ip_prefix},${module.azurerm_public_ip_prefix_egress_003.data.ip_prefix}"
}

output "public_ip_prefix_names" {
  value = {
    egress  = "${module.azurerm_public_ip_prefix_egress_001.data.name},${module.azurerm_public_ip_prefix_egress_002.data.name},${module.azurerm_public_ip_prefix_egress_003.data.name}"
    ingress = module.azurerm_public_ip_prefix_ingress.data.name
  }
}
