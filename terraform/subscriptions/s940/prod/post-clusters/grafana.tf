locals {
  grafana_uris = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://grafana.${k}.radix.equinor.com/login/generic_oauth"
  ]
  grafana_uris_azuread = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://grafana.${k}.radix.equinor.com/login/azuread"
  ]
}

data "azuread_application" "grafana" {
  display_name = "radix-ar-grafana-${module.config.environment}"
}

module "grafana_redirect_uris" {
  source         = "../../../modules/app_registration_redirect_uris"
  application_id = data.azuread_application.grafana.id
  type           = "Web"
  redirect_uris  = concat(["https://grafana.radix.equinor.com/login/generic_oauth"], ["https://grafana.radix.equinor.com/login/azuread"], local.grafana_uris, local.grafana_uris_azuread)
}

module "grafana_fedcred" {
  for_each       = module.clusters.oidc_issuer_url
  source         = "../../../modules/app_application_federated_credentials"
  application_id = data.azuread_application.grafana.id
  display_name   = each.key
  issuer         = each.value
  subject        = "system:serviceaccount:monitor:grafana"
}