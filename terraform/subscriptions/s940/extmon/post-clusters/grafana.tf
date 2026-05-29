

data "azuread_application" "grafana-logreader" {
  display_name = module.config.grafana_ar_reader_display_name
}

data "azuread_application" "grafana" {
  display_name = "radix-ar-grafana-ext-mon"
}

resource "azuread_application_federated_identity_credential" "grafana-logreader" {
  for_each = module.clusters.oidc_issuer_url

  audiences      = ["api://AzureADTokenExchange"]
  display_name   = "k8s-radix-grafana-logreader-${each.key}"
  issuer         = each.value
  subject        = "system:serviceaccount:monitor:grafana"
  application_id = data.azuread_application.grafana-logreader.id
}

module "grafana_redirect_uris" {
  source                = "../../../modules/grafana_redirect_uris"
  application_id        = data.azuread_application.grafana.id
  dns_zone_name         = module.config.dns_zone_name
  cluster_names         = module.clusters.oidc_issuer_url
  grafana_root_hostname = "grafana.ext-mon"
}


module "grafana_fedcred" {
  for_each       = module.clusters.oidc_issuer_url
  source         = "../../../modules/app_application_federated_credentials"
  application_id = data.azuread_application.grafana.id
  display_name   = each.key
  issuer         = each.value
  subject        = "system:serviceaccount:monitor:grafana"
}

# resource "azuread_application_federated_identity_credential" "grafana-mi-fedcred" {
#   for_each = module.clusters.oidc_issuer_url

#   display_name    = "k8s-grafana-${each.key}"
#   audiences       = ["api://AzureADTokenExchange"]
#   issuer         = each.value
#   subject        = "system:serviceaccount:monitor:grafana"
#   application_id = data.azuread_application.grafana-logreader.id
# }

