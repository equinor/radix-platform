module "config" {
  source = "../../../modules/config"
}

module "resourcegroups" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.vnet_resource_group
  location = module.config.location
}

module "azurerm_virtual_network" {
  source              = "../../../modules/virtualnetwork"
  location            = module.config.location
  enviroment          = module.config.environment
  vnet_resource_group = module.resourcegroups.data.name
  private_dns_zones   = tolist(module.config.private_dns_zones_names)
  depends_on          = [module.resourcegroups]
}

module "azurerm_public_ip_prefix_ingress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = var.resource_groups_common_temporary                            #TODO
  publicipprefixname  = "ippre-ingress-radix-aks-${module.config.environment}-prod-001" #TODO
  pipprefix           = "ingress-radix-aks"
  pippostfix          = "prod"
  enviroment          = module.config.environment
  prefix_length       = 29
  publicipcounter     = 8
  # zones               = ["1", "2", "3"]
}

module "azurerm_public_ip_prefix_egress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = var.resource_groups_common_temporary                           #TODO
  publicipprefixname  = "ippre-egress-radix-aks-${module.config.environment}-prod-001" #TODO
  pipprefix           = "egress-radix-aks"
  pippostfix          = "prod"
  enviroment          = module.config.environment
  prefix_length       = 29
  publicipcounter     = 8
}


output "vnet_hub_id" {
  value = module.azurerm_virtual_network.data.vnet_hub.id
}

output "vnet_subnet_id" {
  value = module.azurerm_virtual_network.data.vnet_subnet.id
}

output "public_ip_prefix_ids" {
  value = {
    egress_id  = module.azurerm_public_ip_prefix_egress.data.id
    ingress_id = module.azurerm_public_ip_prefix_ingress.data.id
  }
}
