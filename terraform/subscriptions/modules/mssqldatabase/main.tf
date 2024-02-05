
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
    login_username              = data.azuread_group.admin.display_name
    object_id                   = data.azuread_group.admin.id
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
