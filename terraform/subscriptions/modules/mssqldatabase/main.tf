data "azuread_group" "developers" {
  display_name     = var.admin_adgroup
  security_enabled = true
}

resource "azurerm_mssql_server" "sqlserver" {
  administrator_login           = var.administrator_login
  administrator_login_password  = var.administrator_password
  location                      = var.location
  minimum_tls_version           = var.minimum_tls_version
  name                          = var.server_name
  resource_group_name           = var.rg_name
  tags                          = var.tags
  version                       = var.server_version
  public_network_access_enabled = var.public_network_access_enabled

  azuread_administrator {
    login_username              = data.azuread_group.developers.display_name
    object_id                   = data.azuread_group.developers.id
    azuread_authentication_only = var.azuread_authentication_only
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_mssql_database" "mssql_database" {
  name           = var.database_name
  server_id      = azurerm_mssql_server.sqlserver.id
  collation      = var.collation
  max_size_gb    = var.max_size_gb
  read_scale     = var.read_scale
  sku_name       = var.sku_name
  zone_redundant = var.zone_redundant
  tags           = var.tags
}

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
