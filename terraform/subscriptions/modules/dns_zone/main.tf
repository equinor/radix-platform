resource "azurerm_dns_zone" "this" {
  name                = "${var.dnszoneprefix}radix.equinor.com"
  resource_group_name = var.resourcegroup_common
  tags = {
    IaC = "terraform"
  }
}

output "azurerm_dns_zone_id" {
  value = azurerm_dns_zone.this.id
}
