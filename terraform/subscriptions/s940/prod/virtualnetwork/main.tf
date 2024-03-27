module "config" {
  source = "../../../modules/config"
}

module "resourcegroups" {
  source   = "../../../modules/resourcegroups"
  name     = "cluster-vnet-hub-prod"
  location = module.config.location
}

module "azurerm_virtual_network" {
  source     = "../../../modules/virtualnetwork"
  location   = module.config.location
  enviroment = "prod"
  depends_on = [module.resourcegroups]
}

output "vnet_hub_id" {
  value = module.azurerm_virtual_network.data.vnet_hub.id
}