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

##################################################################################################


# output "vnet_hub_id" {
#   value = module.azurerm_virtual_network.data.vnet_hub.id
# }

# output "vnet_subnet_id" {
#   value = module.azurerm_virtual_network.data.vnet_subnet.id
# }

# output "public_ip_prefix_ids" {
#   value = {
#     egress_id  = module.azurerm_public_ip_prefix_egress.data.id
#     ingress_id = module.azurerm_public_ip_prefix_ingress.data.id
#   }
# }
