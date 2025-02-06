locals {
  grafana_uris = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://grafana.${k}.radix.equinor.com/login/generic_oauth"
  ]
}

data "azuread_application" "grafana" {
  display_name = "radix-ar-grafana-${module.config.environment}"
}

module "grafana_redirect_uris" {
  source         = "../../../modules/app_registration_redirect_uris"
  application_id = data.azuread_application.grafana.id
  type           = "Web"
  redirect_uris  = concat(["https://grafana.radix.equinor.com/login/generic_oauth"], local.grafana_uris)
}