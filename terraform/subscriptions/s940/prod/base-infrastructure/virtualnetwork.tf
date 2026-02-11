module "azurerm_virtual_network" {
  source              = "../../../modules/virtualnetwork"
  location            = module.config.location
  enviroment          = "prod" #TODO
  vnet_resource_group = module.resourcegroup_vnet.data.name
  private_dns_zones   = tolist(module.config.private_dns_zones_names)
  depends_on          = [module.resourcegroup_vnet]
}

module "azurerm_public_ip_prefix_ingress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = module.resourcegroup_clusters.data.name
  publicipprefixname  = "ippre-ingress-radix-aks-production-${module.config.location}-001" #TODO
  pipprefix           = "ingress-radix-aks"
  pippostfix          = module.config.location
  enviroment          = "production"
  prefix_length       = 29
  publicipcounter     = 4
  zones               = ["1", "2", "3"]
}

module "azurerm_public_ip_prefix_egress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = module.resourcegroup_clusters.data.name
  publicipprefixname  = "ippre-radix-aks-production-${module.config.location}-001" #TODO
  pipprefix           = "radix-aks"
  pippostfix          = module.config.location
  enviroment          = "production"
  prefix_length       = 29
  publicipcounter     = 8
}

##################################################################################################
### This block are reserved to new network when Cluster are migrated to platform resources group
###

module "azurerm_virtual_network_platform" {
  source              = "../../../modules/virtualnetwork"
  location            = module.config.location
  enviroment          = module.config.environment
  vnet_resource_group = "cluster-vnet-hub-platform"
  private_dns_zones   = tolist(module.config.private_dns_zones_names)
  depends_on          = [module.resourcegroup_vnet]
}

module "azurerm_public_ip_prefix_ingress_platform" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = module.resourcegroup_clusters.data.name
  publicipprefixname  = "ippre-ingress-radix-aks-platform-${module.config.location}-001" #TODO
  pipprefix           = "ingress-radix-aks"
  pippostfix          = module.config.location
  enviroment          = "platform"
  prefix_length       = 29
  publicipcounter     = 8
  zones               = ["1", "2", "3"]
}

module "azurerm_public_ip_prefix_egress_platform" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = module.resourcegroup_clusters.data.name
  publicipprefixname  = "ippre-radix-aks-platform-${module.config.location}-001" #TODO
  pipprefix           = "radix-aks"
  pippostfix          = module.config.location
  enviroment          = "platform"
  prefix_length       = 28
  publicipcounter     = 16
}

module "azurerm_public_ip_prefix_egress_002" {
  source               = "../../../modules/network_publicipprefix"
  location             = module.config.location
  resource_group_name  = module.resourcegroup_clusters.data.name
  publicipprefixname   = "ippre-radix-aks-platform-${module.config.location}-002" #TODO
  pipprefix            = "radix-aks"
  pippostfix           = module.config.location
  enviroment           = "platform"
  prefix_length        = 28 # Max aivailable /28
  publicipcounter      = 16
  puplicipstartcounter = 17
}

module "azurerm_public_ip_prefix_egress_003" {
  source               = "../../../modules/network_publicipprefix"
  location             = module.config.location
  resource_group_name  = module.resourcegroup_clusters.data.name
  publicipprefixname   = "ippre-radix-aks-platform-${module.config.location}-003" #TODO
  pipprefix            = "radix-aks"
  pippostfix           = module.config.location
  enviroment           = "platform"
  prefix_length        = 28 # Max aivailable /28
  publicipcounter      = 16
  puplicipstartcounter = 33
}
##################################################################################################
## Reserved block C1
##

module "azurerm_public_ip_prefix_egress_004" {
  source               = "../../../modules/network_publicipprefix"
  location             = module.config.location
  resource_group_name  = module.resourcegroup_clusters.data.name
  publicipprefixname   = "ippre-radix-aks-platform-${module.config.location}-004" #TODO
  pipprefix            = "radix-aks"
  pippostfix           = module.config.location
  enviroment           = "platform"
  prefix_length        = 28 # Max aivailable /28
  publicipcounter      = 16
  puplicipstartcounter = 49
  zones               = ["1", "2", "3"]
}

module "azurerm_public_ip_prefix_egress_005" {
  source               = "../../../modules/network_publicipprefix"
  location             = module.config.location
  resource_group_name  = module.resourcegroup_clusters.data.name
  publicipprefixname   = "ippre-radix-aks-platform-${module.config.location}-005" #TODO
  pipprefix            = "radix-aks"
  pippostfix           = module.config.location
  enviroment           = "platform"
  prefix_length        = 28 # Max aivailable /28
  publicipcounter      = 16
  puplicipstartcounter = 65
  zones               = ["1", "2", "3"]
}

module "azurerm_public_ip_prefix_egress_006" {
  source               = "../../../modules/network_publicipprefix"
  location             = module.config.location
  resource_group_name  = module.resourcegroup_clusters.data.name
  publicipprefixname   = "ippre-radix-aks-platform-${module.config.location}-006" #TODO
  pipprefix            = "radix-aks"
  pippostfix           = module.config.location
  enviroment           = "platform"
  prefix_length        = 28 # Max aivailable /28
  publicipcounter      = 16
  puplicipstartcounter = 81
  zones               = ["1", "2", "3"]
}

module "azurerm_public_ip_prefix_egress_007" {
  source               = "../../../modules/network_publicipprefix"
  location             = module.config.location
  resource_group_name  = module.resourcegroup_clusters.data.name
  publicipprefixname   = "ippre-radix-aks-platform-${module.config.location}-007" #TODO
  pipprefix            = "radix-aks"
  pippostfix           = module.config.location
  enviroment           = "platform"
  prefix_length        = 28 # Max aivailable /28
  publicipcounter      = 16
  puplicipstartcounter = 97
  zones               = ["1", "2", "3"]
}



output "egress_ips" {
  value = "${module.azurerm_public_ip_prefix_egress.data.ip_prefix},${module.azurerm_public_ip_prefix_egress_platform.data.ip_prefix},${module.azurerm_public_ip_prefix_egress_002.data.ip_prefix},${module.azurerm_public_ip_prefix_egress_003.data.ip_prefix},${module.azurerm_public_ip_prefix_egress_004.data.ip_prefix},${module.azurerm_public_ip_prefix_egress_005.data.ip_prefix},${module.azurerm_public_ip_prefix_egress_006.data.ip_prefix},${module.azurerm_public_ip_prefix_egress_007.data.ip_prefix}"
}

output "public_ip_prefix_names" {
  value = {
    egress  = "${module.azurerm_public_ip_prefix_egress.data.name},${module.azurerm_public_ip_prefix_egress_platform.data.name},${module.azurerm_public_ip_prefix_egress_002.data.name},${module.azurerm_public_ip_prefix_egress_003.data.name},${module.azurerm_public_ip_prefix_egress_004.data.name},${module.azurerm_public_ip_prefix_egress_005.data.name},${module.azurerm_public_ip_prefix_egress_006.data.name},${module.azurerm_public_ip_prefix_egress_007.data.name}"
    ingress = module.azurerm_public_ip_prefix_ingress.data.name
  }
}
