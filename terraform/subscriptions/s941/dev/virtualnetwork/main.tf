module "resourcegroups" {
  for_each = toset(var.resource_groups)
  source   = "../../../modules/resourcegroups"
  name     = "${each.value}-${local.external_outputs.common.data.enviroment}"
  location = local.external_outputs.common.data.location
}

module "azurerm_virtual_network" {
  source     = "../../../modules/virtualnetwork"
  location   = local.external_outputs.common.data.location
  enviroment = local.external_outputs.common.data.enviroment
}