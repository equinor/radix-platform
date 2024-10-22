data "azurerm_subnet" "subnet" {
  name                 = "private-links"
  virtual_network_name = "vnet-hub"
  resource_group_name  = var.vnet_resource_group
}

resource "azurerm_private_endpoint" "endpoint" {
  for_each            = toset(["qa", "prod"])
  name                = "pe-${var.name}-${each.key}"
  location            = var.location
  resource_group_name = var.vnet_resource_group
  subnet_id           = data.azurerm_subnet.subnet.id
  tags = {
    IaC = "terraform"
  }

  private_service_connection {
    name                           = "pe-${var.name}-${each.key}"
    private_connection_resource_id = azurerm_redis_cache.this[each.key].id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }
}

data "azurerm_private_dns_zone" "dns_zone" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.vnet_resource_group
}
resource "azurerm_private_dns_a_record" "dns_record" {
  for_each            = toset(["qa", "prod"])
  name                = "${var.name}-${each.key}"
  zone_name           = "privatelink.redis.cache.windows.net"
  resource_group_name = var.vnet_resource_group
  ttl                 = 300
  records             = azurerm_private_endpoint.endpoint[each.key].custom_dns_configs[0].ip_addresses
  tags = {
    IaC = "terraform"
  }
}
