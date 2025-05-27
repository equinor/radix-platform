# This MI must not be deleted, has been given Directory Reader role by Equnior AAD Team!
data "azurerm_client_config" "current" {}

module "grafana-mi-server" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-grafana-server-${module.config.environment}"
  resource_group_name = "monitoring"
  location            = module.config.location
}

module "grafana-mi-admin" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-grafana-admin-${module.config.environment}"
  resource_group_name = "monitoring"
  location            = module.config.location
}

resource "azurerm_mysql_flexible_server" "grafana" {
  location                     = module.config.location
  name                         = "${module.config.subscription_shortname}-radix-grafana-${module.config.environment}"
  resource_group_name          = module.config.common_resource_group
  zone                         = 2
  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  sku_name                     = "B_Standard_B1ms"

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
  }
}

resource "azurerm_mysql_flexible_database" "grafana" {
  resource_group_name = azurerm_mysql_flexible_server.grafana.resource_group_name

  name        = "grafana"
  charset     = "latin1"
  collation   = "latin1_swedish_ci"
  server_name = azurerm_mysql_flexible_server.grafana.name
}

# resource "azurerm_mysql_flexible_server_active_directory_administrator" "grafana" {
#   identity_id = module.grafana-mi-server.id
#   login       = data.azuread_group.sql_admin.display_name
#   object_id   = data.azuread_group.sql_admin.object_id
#   server_id   = azurerm_mysql_flexible_server.grafana.id
#   tenant_id   = data.azurerm_client_config.current.tenant_id
# }


output "mi-admin-client-id" {
  value = module.grafana-mi-admin.client-id
}
output "mi-admin-name" {
  value = module.grafana-mi-admin.name
}

output "mi-server-client-id" {
  value = module.grafana-mi-server.client-id
}
output "mi-server-name" {
  value = module.grafana-mi-server.name
}