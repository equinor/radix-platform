locals {
  grafana_uris = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://grafana.${k}.${module.config.environment}.radix.equinor.com/login/generic_oauth"
  ]
}

module "grafana" {
  source       = "../../../modules/app_registration"
  display_name = "ar-radix-grafana-${module.config.environment}"
  notes        = "Grafana Oauth, main app for user authentication to Grafana"
  service_id   = "110327"
  web_uris     = concat(["https://grafana.${module.config.environment}.radix.equinor.com/login/generic_oauth"], local.grafana_uris)
  owners       = data.azuread_group.radix.members

}