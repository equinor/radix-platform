locals {
  private_dns_zone_names = [
    "privatelink.monitor.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.agentsvc.azure-automation.net",
    "privatelink.blob.core.windows.net",
  ]

  private_dns_zone_ids = [
    for zone in local.private_dns_zone_names : var.private_dns_zones[zone].id
  ]
}

resource "azurerm_monitor_private_link_scope" "this" {
  name                  = var.ampls_name
  resource_group_name   = var.resource_group_name
  ingestion_access_mode = "PrivateOnly" # Switch to "PrivateOnly" after testing - Valid values are "Open" or "PrivateOnly"
  query_access_mode     = "PrivateOnly" # Switch to "PrivateOnly" after testing - Valid values are "Open" or "PrivateOnly"
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_private_endpoint" "this" {
  name                = var.private_endpoint_name
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_monitor_private_link_scope.this.id
    subresource_names              = ["azuremonitor"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "azuremonitor"
    private_dns_zone_ids = local.private_dns_zone_ids
  }

  tags = {
    IaC = "terraform"
  }
}

output "id" {
  description = "ID of the AMPLS instance."
  value       = azurerm_monitor_private_link_scope.this.id
}

output "name" {
  description = "Name of the AMPLS instance."
  value       = azurerm_monitor_private_link_scope.this.name
}