terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_private_dns_zone" "private-azurecr-io" {
  name = "privatelink.azurecr.io"
  resource_group_name = var.vnet_rg_names.dev
}

resource "azurerm_user_assigned_identity" "RADIX_ACR_CACHE" {
  name                = "id_radix_acr_cache-${var.RADIX_ENVIRONMENT}-${var.AZ_LOCATION}"
  location            = var.AZ_LOCATION
  resource_group_name = var.AZ_RESOURCE_GROUP_COMMON
}


resource "azurerm_container_registry" "RADIX_CACHE" {
  name                    = "radix${var.RADIX_ENVIRONMENT}cache"
  location                = var.AZ_LOCATION
  sku                     = "Premium"
  resource_group_name     = var.AZ_RESOURCE_GROUP_COMMON
  zone_redundancy_enabled = false
  admin_enabled           = false
  anonymous_pull_enabled  = false

  public_network_access_enabled = false
}

resource "azurerm_role_assignment" "RADIX_ACR_CACHE_PULL" {
  principal_id                     = azurerm_user_assigned_identity.RADIX_ACR_CACHE.principal_id
  scope                            = azurerm_container_registry.RADIX_CACHE.id
  role_definition_name             = "AcrPull"
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "RADIX_ACR_CACHE_PUSH" {
  principal_id                     = azurerm_user_assigned_identity.RADIX_ACR_CACHE.principal_id
  scope                            = azurerm_container_registry.RADIX_CACHE.id
  role_definition_name             = "AcrPush"
  skip_service_principal_aad_check = true
}

resource "azurerm_private_endpoint" "acr_dev" {
  # for_each = { for key, value in var.private_link : key => var.private_link[key]  }
  name                = "pe-radix-acr-cache-${var.RADIX_ENVIRONMENT}"
  resource_group_name = var.AZ_RESOURCE_GROUP_COMMON
  location            = var.AZ_LOCATION
  subnet_id           = var.private_link["dev"].linkname # each.value.linkname

  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_container_registry.RADIX_CACHE.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "dns-acr-cache-${var.RADIX_ENVIRONMENT}"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.private-azurecr-io.id]
  }
}
