resource "azurerm_container_registry" "app" {
  for_each = var.K8S_ENVIROMENTS

  name                    = "radix${each.key}app"
  location                = var.resource_groups[each.value.resourceGroup].location # Create ACR in same location as k8s
  sku                     = "Premium"
  resource_group_name     = var.AZ_RESOURCE_GROUP_COMMON
  zone_redundancy_enabled = false
  admin_enabled           = false
  anonymous_pull_enabled  = false

  public_network_access_enabled = true

  network_rule_set {
    default_action = "Deny"
    ip_rule        = [
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
}


locals {
  acrDnsRecords = flatten([
    for key, value in var.K8S_ENVIROMENTS :
    [
      for ip in azurerm_private_endpoint.acr_app[key].custom_dns_configs :
      {
        ips : ip.ip_addresses,
        fqdn : ip.fqdn,
        subdomain : replace(ip.fqdn, ".azurecr.io", ""),
        env : key
      }
    ]
  ])
}

resource "azurerm_private_dns_a_record" "dns_record" {
  # Adds a unique key to each value to use it in for_each
  for_each = {for value in local.acrDnsRecords : join("-", [value.env, value.subdomain]) => value}

  name                = each.value.subdomain
  zone_name           = azurerm_private_dns_zone.zone[each.value.env].name
  resource_group_name = join("", ["cluster-vnet-hub-", each.value.env])
  ttl                 = 300
  records             = each.value.ips

  depends_on = [azurerm_private_endpoint.acr_app]
}
