module "azurerm_virtual_network" {
  source     = "../../../modules/virtualnetwork"
  location   = local.external_outputs.common.data.location
  enviroment = local.external_outputs.common.data.enviroment_S
}
