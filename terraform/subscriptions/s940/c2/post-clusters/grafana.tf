locals {
  grafana_uris = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://grafana.${k}.c2.radix.equinor.com/login/generic_oauth"
  ]
}

module "grafana_redirect_uris" {
  source         = "../../../modules/app_registration_redirect_uris"
  application_id = "/applications/${module.config.appreg.grafana}"
  type           = "Web"
  redirect_uris  = concat(["https://grafana.c2.radix.equinor.com/login/generic_oauth"], local.grafana_uris)
}