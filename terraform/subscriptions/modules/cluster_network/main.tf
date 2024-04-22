resource "azurerm_network_security_group" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "nsg-${var.cluster_name}-rule"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "20.223.40.150"
  }

  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.cluster_name}"
  resource_group_name = var.resource_group_name
  address_space       = ["10.5.0.0/16"] # parameter of free space
  location            = var.location
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_subnet" "this" {
  name                 = "subnet-${var.cluster_name}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.5.0.0/18"] # Prefix of vnet name
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}