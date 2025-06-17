# This MI must not be deleted, has been given Directory Reader role by Equnior AAD Team!
data "azurerm_client_config" "current" {}

module "grafana-mi-server" {
  source              = "../../modules/userassignedidentity"
  name                = "radix-id-grafana-server-${var.environment}"
  resource_group_name = var.common_resource_group
  location            = var.location
}

module "grafana-mi-admin" {
  source              = "../../modules/userassignedidentity"
  name                = "radix-id-grafana-admin-${var.environment}"
  resource_group_name = var.common_resource_group
  location            = var.location
}

# resource "azurerm_mysql_flexible_server" "grafana" {
#   location                     = var.location
#   name                         = "radix-grafana-${var.environment}"
#   resource_group_name          = var.common_resource_group
#   zone                         = 2
#   backup_retention_days        = 14
#   geo_redundant_backup_enabled = true
#   sku_name                     = "B_Standard_B1ms"
#   administrator_login          = "radix"


#   tags = {
#     IaC = "terraform"
#   }

#   storage {
#     auto_grow_enabled  = true
#     io_scaling_enabled = false
#     iops               = 360
#     size_gb            = 20
#   }

#   identity {
#     identity_ids = [module.grafana-mi-server.id]
#     type         = "UserAssigned"
#   }
# }



# resource "azurerm_mysql_flexible_database" "grafana" {
#   resource_group_name = azurerm_mysql_flexible_server.grafana.resource_group_name
#   name                = "grafana"
#   charset             = "latin1"
#   collation           = "latin1_swedish_ci"
#   server_name         = azurerm_mysql_flexible_server.grafana.name
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