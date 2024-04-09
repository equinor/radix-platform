data "azurerm_resource_group" "resourcegroup" {
  name = var.resource_group_name
}

resource "azurerm_public_ip_prefix" "publicipprefix" {
  name                = var.publicipprefixname
  location            = var.location
  resource_group_name = var.resource_group_name
  prefix_length       = var.prefix_length
  zones               = var.zones
  sku                 = "Standard"
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_public_ip" "this" {
  count                   = var.publicipcounter
  name                    = "pip-${var.pipprefix}-${var.enviroment}-${var.pippostfix}-00${count.index + 1}"
  public_ip_prefix_id     = resource.azurerm_public_ip_prefix.publicipprefix.id
  resource_group_name     = var.resource_group_name
  location                = var.location
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30
  zones                   = var.zones
  sku                     = "Standard"
  tags = {
    IaC = "terraform"
  }
}

