# This MI must not be deleted, has been given Directory Reader role by Equnior AAD Team!
# data "azurerm_client_config" "current" {}

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

module "grafana" {
  source                       = "../../../modules/mysql_flexible"
  administrator_login          = "radixadmin"
  location                     = module.config.location
  server_name                  = "radix-grafana-${module.config.environment}"
  resource_group_name          = module.config.common_resource_group
  geo_redundant_backup_enabled = false # Disabled geo-redundant backup since it's not supported in the swedencentral region.
  sku_name                     = "B_Standard_B2ms"
  mysql_version                = 8.4
  identity_ids                 = module.grafana-mi-server.id
  sql_admin_display_name       = "Radix SQL server admin - c2"
  database_name                = "grafana"
  vnet_resource_group          = module.config.vnet_resource_group


}
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