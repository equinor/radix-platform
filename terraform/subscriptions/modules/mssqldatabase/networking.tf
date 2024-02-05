

data "azurerm_subnet" "subnet" {
  name                 = "private-links"
  virtual_network_name = var.virtual_network
  resource_group_name  = "cluster-vnet-hub-${var.env}"
}

resource "azurerm_private_endpoint" "endpoint" {
  name                = "pe-${var.server_name}"
  location            = var.location
  resource_group_name = var.rg_name #TODO: Burde denne ligge i samme ressursgruppe som mssql server, eller som dns sonen?
  subnet_id           = data.azurerm_subnet.subnet.id

  private_service_connection {
    name                           = "pe-${var.server_name}"
    private_connection_resource_id = azurerm_mssql_server.sqlserver.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
}

data "azurerm_private_dns_zone" "dns_zone" {
  name                = "privatelink.database.windows.net"
  resource_group_name = "cluster-vnet-hub-${var.env}"
}
resource "azurerm_private_dns_a_record" "dns_record" {
  name                = var.server_name
  zone_name           = "privatelink.database.windows.net"
  resource_group_name = "cluster-vnet-hub-${var.env}"
  ttl                 = 300
  records             = azurerm_private_endpoint.endpoint.custom_dns_configs[0].ip_addresses
}
