module "grafana" {
  source       = "../../../modules/app_registration"
  display_name = "radix-ar-grafana-${module.config.environment}"
  notes        = "Grafana Oauth, main app for user authentication to Grafana"
  service_id   = "110327"
  owners       = keys(jsondecode(data.azurerm_key_vault_secret.radixowners.value))
}