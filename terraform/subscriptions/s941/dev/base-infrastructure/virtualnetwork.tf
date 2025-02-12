module "azurerm_virtual_network" {
  source              = "../../../modules/virtualnetwork"
  location            = module.config.location
  enviroment          = module.config.environment
  vnet_resource_group = module.vnet_resourcegroup.data.name
  private_dns_zones   = tolist(module.config.private_dns_zones_names)
  depends_on          = [module.vnet_resourcegroup]
}

module "azurerm_public_ip_prefix_ingress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = var.resource_groups_common_legacy                                                   #TODO
  publicipprefixname  = "ippre-ingress-radix-aks-${var.enviroment_temporary}-${module.config.location}-001" #TODO
  pipprefix           = "ingress-radix-aks"
  pippostfix          = module.config.location
  enviroment          = var.enviroment_temporary #TODO
  prefix_length       = 30
  zones               = ["1", "2", "3"]
}

module "azurerm_public_ip_prefix_egress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = var.resource_groups_common_legacy                                           #TODO
  publicipprefixname  = "ippre-radix-aks-${var.enviroment_temporary}-${module.config.location}-001" #TODO
  pipprefix           = "radix-aks"
  pippostfix          = module.config.location
  enviroment          = var.enviroment_temporary #TODO
  prefix_length       = 30
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
