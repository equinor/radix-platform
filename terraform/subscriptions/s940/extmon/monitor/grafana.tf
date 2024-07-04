
data "azurerm_key_vault" "this" {
  name                = module.config.key_vault_name
  resource_group_name = module.config.common_resource_group
}

data "azurerm_key_vault_secret" "grafana-admin-password" {
  name         = "mysql-grafana-prod-admin-password"
  key_vault_id = data.azurerm_key_vault.this.id
}

# This MI must not be deleted, has been given Directory Reader role by Equnior AAD Team!
module "grafana-mi-server" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-grafana-server-${module.config.environment}"
  resource_group_name = "monitoring"
  location            = module.config.location
}

resource "azurerm_mysql_flexible_server" "grafana" {
  location               = module.config.location
  name                   = "${module.config.subscription_shortname}-radix-grafana-${module.config.environment}-prod"
  resource_group_name    = "monitoring"
  zone                   = 2
  backup_retention_days  = 35
  sku_name               = "B_Standard_B2ms"
  administrator_login    = "radixadmin"
  administrator_password = data.azurerm_key_vault_secret.grafana-admin-password.value

  tags = {
    IaC = "terraform"
  }

  identity {
    identity_ids = [module.grafana-mi-server.id]
    type         = "UserAssigned"
  }

  storage {
    auto_grow_enabled  = true
    io_scaling_enabled = false
    iops               = 360
    size_gb            = 20
  }

}

resource "azurerm_mysql_flexible_database" "grafana" {
  resource_group_name = azurerm_mysql_flexible_server.grafana.resource_group_name

  name        = "grafana"
  charset     = "latin1"
  collation   = "latin1_swedish_ci"
  server_name = azurerm_mysql_flexible_server.grafana.name
}

resource "azurerm_mysql_flexible_server_active_directory_administrator" "grafana" {
  identity_id = module.grafana-mi-server.id
  login       = var.admin-group-name
  object_id   = data.azuread_group.mssql-developers.object_id
  server_id   = azurerm_mysql_flexible_server.grafana.id
  tenant_id   = data.azurerm_client_config.current.tenant_id
}
