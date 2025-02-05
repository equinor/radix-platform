module "config" {
  source = "../../../modules/config"
}

data "azurerm_client_config" "current" {}

output "mi-server-client-id" {
  value = module.grafana-mi-server.client-id
}
output "mi-server-name" {
  value = module.grafana-mi-server.name
}
