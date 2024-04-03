resource "azurerm_virtual_network" "vnet-hub" {
  name                = "vnet-hub"
  resource_group_name = "cluster-vnet-hub-${var.enviroment}"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_subnet" "this" {
  name                 = "private-links"
  resource_group_name  = "cluster-vnet-hub-${var.enviroment}"
  virtual_network_name = azurerm_virtual_network.vnet-hub.name
  address_prefixes     = ["10.0.0.0/18"]
  service_endpoints    = ["Microsoft.Storage"] #["Microsoft.Storage"],"Microsoft.ContainerRegistry","Microsoft.KeyVault","Microsoft.Sql","Microsoft.Storage"]
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = toset(local.AZ_PRIVATE_DNS_ZONES)
  name                = each.key
  resource_group_name = module.config.vnet_resource_group
  tags = {
    IaC = "terraform"
  }
}