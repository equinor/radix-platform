resource "azurerm_virtual_network" "vnet-hub" {
  name                = "vnet-hub"
  resource_group_name = "cluster-vnet-hub-${var.enviroment}"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
}
