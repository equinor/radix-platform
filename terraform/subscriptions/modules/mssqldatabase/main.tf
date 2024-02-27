
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
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.server.id]
  }
  primary_user_assigned_identity_id = azurerm_user_assigned_identity.server.id

  lifecycle {
    prevent_destroy = true
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
  tags           = var.database_tags
  depends_on     = [azurerm_mssql_server.sqlserver]
  long_term_retention_policy {
    monthly_retention = "PT0S"
    week_of_year      = 1
    weekly_retention  = "PT0S"
    yearly_retention  = "PT0S"
  }
  short_term_retention_policy {
    backup_interval_in_hours = 24
    retention_days           = 7
  }
  threat_detection_policy {
    disabled_alerts      = []
    email_account_admins = "Disabled"
    email_addresses      = []
    retention_days       = 0
    state                = "Disabled"
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "azurerm_storage_account" "this" {
  name                = var.audit_storageaccount_name
  resource_group_name = var.common_resource_group
}
resource "azurerm_mssql_server_extended_auditing_policy" "this" {
  server_id              = azurerm_mssql_server.sqlserver.id
  storage_endpoint       = data.azurerm_storage_account.this.primary_blob_endpoint
  retention_in_days      = 7
  log_monitoring_enabled = false

  // Creating the policy will fail if the role assignment is not made yet
  depends_on = [azurerm_role_assignment.auditlog]
}
