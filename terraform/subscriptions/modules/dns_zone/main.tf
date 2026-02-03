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

output "azurerm_dns_resource_group_name" {
  value = azurerm_dns_zone.this.resource_group_name
}

resource "azurerm_dns_caa_record" "this" {
  for_each            = var.dnszoneprefix == "" ? { "dns_caa_record" : true } : {}
  name                = "@"
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = azurerm_dns_zone.this.resource_group_name
  ttl                 = 3600

  record {
    flags = 0
    tag   = "issue"
    value = "godaddy.com"
  }

  record {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
  }

  record {
    flags = 0
    tag   = "issue"
    value = "digicert.com"
  }

}
