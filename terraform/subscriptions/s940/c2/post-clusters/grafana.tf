locals {
  grafana_uris = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://grafana.${k}.c2.radix.equinor.com/login/generic_oauth"
  ]
}

module "grafana" {
  source       = "../../../modules/app_registration"
  display_name = "ar-radix-grafana-c2-prod" #TODO
  notes        = "Grafana Oauth, main app for user authentication to Grafana"
  service_id   = "110327"
  web_uris     = concat(["https://grafana.c2.radix.equinor.com/login/generic_oauth"], local.grafana_uris)
  owners       = data.azuread_group.radix.members
}