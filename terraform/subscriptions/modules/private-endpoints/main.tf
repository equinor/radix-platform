locals {
  dnszone = lookup(var.subresourcename_dns, "${var.subresourcename}", "")
}

data "azurerm_subnet" "this" {
  name                 = "private-links"
  virtual_network_name = var.virtual_network
  resource_group_name  = var.vnet_resource_group
}

data "azurerm_private_dns_zone" "this" {
  name                = local.dnszone
  resource_group_name = var.vnet_resource_group
}

resource "azurerm_private_endpoint" "this" {
  name                = "pe-${var.server_name}"
  location            = var.location
  resource_group_name = var.vnet_resource_group
  subnet_id           = data.azurerm_subnet.this.id
  tags = {
    IaC = "terraform"
  }

  dynamic "private_service_connection" {
    for_each = var.manual_connection == true ? [1] : []
    content {
      name                           = "pe-${var.server_name}"
      private_connection_resource_id = var.resource_id
      subresource_names              = [var.subresourcename]
      is_manual_connection           = var.manual_connection
      request_message                = "RadixPrivateLink"
    }
  }

  dynamic "private_service_connection" {
    for_each = var.manual_connection == false ? [1] : []
    content {
      name                           = "pe-${var.server_name}"
      private_connection_resource_id = var.resource_id
      subresource_names              = [var.subresourcename]
      is_manual_connection           = var.manual_connection
    }
  }

  dynamic "private_dns_zone_group" {
    for_each = var.manual_connection == true ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [data.azurerm_private_dns_zone.this.id]
    }
  }
}

resource "azurerm_private_dns_a_record" "this" {
  name                = var.server_name
  zone_name           = local.dnszone
  resource_group_name = var.vnet_resource_group
  ttl                 = 300
  records             = [azurerm_private_endpoint.this.private_service_connection[0].private_ip_address]
  tags = {
    IaC = "terraform"
  }
}


