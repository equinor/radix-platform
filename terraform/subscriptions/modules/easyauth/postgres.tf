data "azurerm_client_config" "current" {}

data "azuread_group" "postgres_admin" {
  display_name     = var.postgres_admin_group_name
  security_enabled = true
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                          = var.postgres_server_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  version                       = var.postgres_version
  sku_name                      = var.postgres_sku_name
  storage_mb                    = var.postgres_storage_mb
  auto_grow_enabled             = true
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  public_network_access_enabled = false

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  tags = {
    IaC = "terraform"
  }

  lifecycle {
    # Azure picks the zone when none is given
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "dex" {
  name      = "dex"
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "admin_group" {
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = azurerm_postgresql_flexible_server.this.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azuread_group.postgres_admin.object_id
  principal_name      = data.azuread_group.postgres_admin.display_name
  principal_type      = "Group"
}

# Dex runs its own schema migrations, so its identity gets admin rights through the admin group.
# Group members log in with the group name as the Postgres user name.
resource "azuread_group_member" "dex" {
  group_object_id  = data.azuread_group.postgres_admin.object_id
  member_object_id = module.dex_identity.principal_id
}

data "azurerm_subnet" "private_links" {
  name                 = "private-links"
  virtual_network_name = "vnet-hub"
  resource_group_name  = var.vnet_resource_group
}

data "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.vnet_resource_group
}

resource "azurerm_private_endpoint" "postgres" {
  name                = "pe-${azurerm_postgresql_flexible_server.this.name}"
  location            = var.location
  resource_group_name = var.vnet_resource_group
  subnet_id           = data.azurerm_subnet.private_links.id
  tags = {
    IaC = "terraform"
  }

  private_service_connection {
    name                           = "pe-${azurerm_postgresql_flexible_server.this.name}"
    private_connection_resource_id = azurerm_postgresql_flexible_server.this.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.postgres.id]
  }
}
