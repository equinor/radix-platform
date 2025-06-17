module "azurerm_virtual_network" {
  source              = "../../modules/virtualnetwork"
  location            = var.location
  enviroment          = var.environment
  vnet_resource_group = module.resourcegroup_vnet.data.name
  private_dns_zones = var.private_dns_zones_names
  depends_on          = [module.resourcegroup_vnet]
  testzone            = var.testzone

}

module "azurerm_public_ip_prefix_ingress" {
  source              = "../../modules/network_publicipprefix"
  location            = var.location
  resource_group_name = module.resourcegroup_clusters.data.name
  publicipprefixname  = "ippre-ingress-radix-aks-d1-${var.environment}-001" # template
  pipprefix           = "ingress-radix-aks"
  pippostfix          = "prod"
  enviroment          = var.environment
  prefix_length       = 29
  publicipcounter     = 8
  depends_on          = [module.resourcegroup_clusters]
  # zones               = ["1", "2", "3"]
  testzone = var.testzone
}

module "azurerm_public_ip_prefix_egress" {
  source              = "../../modules/network_publicipprefix"
  location            = var.location
  resource_group_name = module.resourcegroup_clusters.data.name
  publicipprefixname  = "ippre-radix-aks-d1-${var.environment}-001" # template
  pipprefix           = "radix-aks"
  pippostfix          = var.location
  enviroment          = "d1" # template
  prefix_length       = 28
  publicipcounter     = 16
  depends_on          = [module.resourcegroup_clusters]
  testzone            = var.testzone

}

output "egress_ips" {
  value = module.azurerm_public_ip_prefix_egress.data.ip_prefix # template
}

output "public_ip_prefix_names" {
  value = {
    egress  = module.azurerm_public_ip_prefix_egress.data.name
    ingress = module.azurerm_public_ip_prefix_ingress.data.name
  }
}
