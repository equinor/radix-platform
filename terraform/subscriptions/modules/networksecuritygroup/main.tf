resource "azurerm_network_security_group" "networksecuritygroup" {
  name                = var.networksecuritygroupname
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    IaC = "terraform"
  }

  security_rule = [
    {
      access                                     = "Allow"
      description                                = ""
      destination_address_prefix                 = var.destination_address_prefix
      destination_address_prefixes               = []
      destination_application_security_group_ids = []
      destination_port_range                     = ""
      destination_port_ranges = [
        "443",
        "80",
      ]
      direction                             = "Inbound"
      name                                  = "${var.networksecuritygroupname}-rule"
      priority                              = 100
      protocol                              = "Tcp"
      source_address_prefix                 = "*"
      source_address_prefixes               = []
      source_application_security_group_ids = []
      source_port_range                     = "*"
      source_port_ranges                    = []
    }
  ]

}
