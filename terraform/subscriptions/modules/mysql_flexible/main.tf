data "azurerm_client_config" "current" {}

data "azuread_group" "sql_admin" {
  display_name     = var.sql_admin_display_name
  security_enabled = true
}

resource "random_password" "grafana_mysql_admin" {
  length  = 32
  special = true
}

resource "azurerm_mysql_flexible_server" "this" {
  administrator_login          = var.administrator_login
  administrator_password       = random_password.grafana_mysql_admin.result # just a dummy password, not used when AD auth is setup
  location                     = var.location
  name                         = var.server_name
  resource_group_name          = var.resource_group_name
  zone                         = var.zone
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled
  sku_name                     = var.sku_name
  version                      = var.mysql_version
  public_network_access        = "Disabled"


  tags = {
    IaC = "terraform"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      var.identity_ids
    ]
  }

  storage {
    auto_grow_enabled  = true
    io_scaling_enabled = false
    iops               = 360
  }
}

resource "azurerm_mysql_flexible_database" "this" {
  resource_group_name = azurerm_mysql_flexible_server.this.resource_group_name

  name        = var.database_name
  charset     = "latin1"
  collation   = "latin1_swedish_ci"
  server_name = azurerm_mysql_flexible_server.this.name
}

resource "azurerm_mysql_flexible_server_active_directory_administrator" "this" {
  identity_id = var.identity_ids
  login       = data.azuread_group.sql_admin.display_name
  object_id   = data.azuread_group.sql_admin.object_id
  server_id   = azurerm_mysql_flexible_server.this.id
  tenant_id   = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_mysql_flexible_server_configuration" "disable_autopk" {
  name                = "sql_generate_invisible_primary_key"
  resource_group_name = var.resource_group_name
  server_name         = var.server_name
  value               = var.generate_invisible_primary
}
