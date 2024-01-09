output "data" {
  description = "IDs of virtualnetworks"
  value = {
    "vnet_hub"         = azurerm_virtual_network.vnet-hub
    "vnet_subnet"      = azurerm_subnet.this
    "private_dns_zone" = azurerm_private_dns_zone.this
  }
}
