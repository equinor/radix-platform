module "azurerm_virtual_network" {
  source     = "../../../modules/virtualnetwork"
  location   = local.external_outputs.clusters.data.location
  enviroment = local.external_outputs.clusters.data.enviroment
}

