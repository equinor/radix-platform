module "config" {
  source = "../../../modules/config"
}

data "azurerm_client_config" "current" {}

data "azuread_group" "mssql_admin" {
  display_name     = "Radix SQL server admin - platform" #TODO
  security_enabled = true
}

output "mi-server-client-id" {
  value = module.grafana-mi-server.client-id
}
output "mi-server-name" {
  value = module.grafana-mi-server.name
}
