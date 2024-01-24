resource "azurerm_container_registry" "app" {
  for_each = var.K8S_ENVIROMENTS

  name                    = "radix${each.key}app${var.ACR_SUFFIX}"
  location                = var.resource_groups[each.value.resourceGroup].location # Create ACR in same location as k8s
  sku                     = "Premium"
  resource_group_name     = var.AZ_RESOURCE_GROUP_COMMON
  zone_redundancy_enabled = false
  admin_enabled           = false
  anonymous_pull_enabled  = false

  public_network_access_enabled = true

  network_rule_set {
    default_action = "Deny"
    ip_rule = [
      {
        action   = "Allow"
        ip_range = var.EQUINOR_WIFI_IP_CIDR
      }
    ]
  }

  georeplications {
    location                = var.resource_groups[each.value.resourceGroup].location == "northeurope" ? "westeurope" : "northeurope"
    zone_redundancy_enabled = false
  }
}
# Link ACR To `vnet-hub`
resource "azurerm_private_endpoint" "acr_app" {
  for_each = var.K8S_ENVIROMENTS

  name                = "pe-radix-acr-app-${each.key}"
  resource_group_name = var.AZ_RESOURCE_GROUP_COMMON
  location            = var.resource_groups[each.value.resourceGroup].location # Create ACR in same location as k8s
  subnet_id           = var.private_link[each.key].linkname

  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_container_registry.app[each.key].id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  lifecycle {
    ignore_changes = ["private_dns_zone_group"]
  }
}
