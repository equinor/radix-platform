locals {
  dnszone       = lookup(var.subresourcename_dns, "${var.subresourcename}", "")
  customdnszone = join("/", concat(slice(split("/", data.azurerm_private_dns_zone.this.id), 0, length(split("/", data.azurerm_private_dns_zone.this.id)) - 1), [var.customdnszone]))
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
  name                = var.server_name
  location            = var.location
  resource_group_name = var.vnet_resource_group
  subnet_id           = data.azurerm_subnet.this.id

  lifecycle {
    ignore_changes = [
      private_service_connection[0].request_message
    ]
  }
  tags = {
    IaC = "terraform"
  }

  dynamic "private_service_connection" {
    for_each = var.subresourcename != "privatelinkservice" ? [1] : []
    content {
      name                           = var.server_name
      private_connection_resource_id = var.resource_id
      subresource_names              = [var.subresourcename]
      is_manual_connection           = var.manual_connection
      request_message                = "Radix Private Link"
    }
  }

  dynamic "private_service_connection" {
    for_each = var.subresourcename == "privatelinkservice" ? [1] : []
    content {
      name                           = var.server_name
      private_connection_resource_id = var.resource_id
      is_manual_connection           = true
      request_message                = "Radix Private Link"
    }
  }

  dynamic "private_dns_zone_group" {
    for_each = var.customdnszone == "" ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [data.azurerm_private_dns_zone.this.id]
    }
  }

  dynamic "private_dns_zone_group" {
    for_each = var.customdnszone != "" ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids = [local.customdnszone]
    }
  }
}

resource "azurerm_private_dns_a_record" "this" {
  name                = var.customname != "" ? var.customname : lower(element(split("/", azurerm_private_endpoint.this.private_service_connection[0].private_connection_resource_id), length(split("/", azurerm_private_endpoint.this.private_service_connection[0].private_connection_resource_id)) - 1))
  zone_name           = var.customdnszone != "" ? var.customdnszone : local.dnszone
  resource_group_name = var.vnet_resource_group
  ttl                 = 10
  records             = [azurerm_private_endpoint.this.private_service_connection[0].private_ip_address]
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
  tags = {
    IaC = "terraform"
  }
}


