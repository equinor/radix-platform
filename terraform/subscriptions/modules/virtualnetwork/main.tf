resource "azurerm_virtual_network" "vnet-hub" {
  name                = "vnet-hub"
  resource_group_name = "cluster-vnet-hub-${var.enviroment}"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  tags = {
    IaC = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_subnet" "this" {
  name                              = "private-links"
  resource_group_name               = var.vnet_resource_group
  virtual_network_name              = azurerm_virtual_network.vnet-hub.name
  address_prefixes                  = ["10.0.0.0/18"]
  service_endpoints                 = ["Microsoft.Storage"] #"["Microsoft.Storage","Microsoft.ContainerRegistry","Microsoft.KeyVault","Microsoft.Sql","Microsoft.Storage"]
  private_endpoint_network_policies = "Disabled"
  depends_on = [ azurerm_virtual_network.vnet-hub ]
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = toset(var.private_dns_zones)
  name                = each.key
  resource_group_name = var.vnet_resource_group
  tags = {
    IaC = "terraform"
  }
}

output "azurerm_virtual_network_id" {
  value = azurerm_virtual_network.vnet-hub.id
}

output "azurerm_subnet_id" {
  value = azurerm_subnet.this.id
}