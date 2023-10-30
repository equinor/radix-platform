resource "azurerm_container_registry" "app" {
  for_each = toset(var.K8S_ENVIROMENTS)

  name                    = "radix${each.value}app"
  location                = var.AZ_LOCATION
  sku                     = "Premium"
  resource_group_name     = var.AZ_RESOURCE_GROUP_COMMON
  zone_redundancy_enabled = false
  admin_enabled           = false
  anonymous_pull_enabled  = false

  public_network_access_enabled = false
}

resource "azurerm_private_endpoint" "acr_app" {
  for_each = toset(var.K8S_ENVIROMENTS)

  name                = "pe-radix-acr-app-${each.value}"
  resource_group_name = var.AZ_RESOURCE_GROUP_COMMON
  location            = var.AZ_LOCATION
  subnet_id           = var.private_link[each.key].linkname

  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_container_registry.app[each.key].id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "dns-acr-app-${each.value}"
    private_dns_zone_ids = [azurerm_private_dns_zone.zone[each.key].id]
  }
}
