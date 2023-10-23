resource "azurerm_container_registry" "acr" {
  for_each = toset(var.K8S_ENVIROMENTS)

  name                    = "radix${each.value}cache"
  location                = var.AZ_LOCATION
  sku                     = "Premium"
  resource_group_name     = var.AZ_RESOURCE_GROUP_COMMON
  zone_redundancy_enabled = false
  admin_enabled           = false
  anonymous_pull_enabled  = false

  public_network_access_enabled = false
}

resource "azurerm_private_endpoint" "acr_dev" {
  for_each = toset(var.K8S_ENVIROMENTS)

  name                = "pe-radix-acr-cache-${each.value}"
  resource_group_name = var.AZ_RESOURCE_GROUP_COMMON
  location            = var.AZ_LOCATION
  subnet_id           = var.private_link[each.key].linkname

  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_container_registry.acr[each.key].id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "dns-acr-cache-${each.value}"
    private_dns_zone_ids = [azurerm_private_dns_zone.zone[each.key].id]
  }
}


# Access control

resource "azurerm_user_assigned_identity" "acr_id" {
  for_each = toset(var.K8S_ENVIROMENTS)

  name                = "id_radix_acr_cache-${each.value}-${var.AZ_LOCATION}"
  location            = var.AZ_LOCATION
  resource_group_name = var.AZ_RESOURCE_GROUP_COMMON
}

resource "azurerm_role_assignment" "RADIX_ACR_CACHE_PULL" {
  for_each = toset(var.K8S_ENVIROMENTS)

  principal_id                     = azurerm_user_assigned_identity.acr_id[each.key].principal_id
  scope                            = azurerm_container_registry.acr[each.key].id
  role_definition_name             = "AcrPull"
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "RADIX_ACR_CACHE_PUSH" {
  for_each = toset(var.K8S_ENVIROMENTS)

  principal_id                     = azurerm_user_assigned_identity.acr_id[each.key].principal_id
  scope                            = azurerm_container_registry.acr[each.key].id
  role_definition_name             = "AcrPush"
  skip_service_principal_aad_check = true
}
