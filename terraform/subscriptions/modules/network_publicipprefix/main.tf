data "azurerm_resource_group" "resourcegroup" {
  name = var.resource_group_name
}

resource "azurerm_public_ip_prefix" "publicipprefix" {
  name                = var.publicipprefixname
  location            = var.location
  resource_group_name = var.resource_group_name
  prefix_length       = 30
  zones               = var.zones
  tags = {
    IaC = "terraform"
  }
}
