module "azurerm_virtual_network" {
  source     = "../../../modules/virtualnetwork"
  location   = local.external_outputs.clusters.outputs.clusters.location
  enviroment = local.external_outputs.clusters.outputs.clusters.enviroment
}
