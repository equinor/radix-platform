data "azuread_application" "grafana" {
  display_name = "radix-ar-grafana-${module.config.environment}"
}

module "grafana_redirect_uris" {
  source         = "../../../modules/grafana_redirect_uris"
  application_id = data.azuread_application.grafana.id
  dns_zone_name  = module.config.dns_zone_name
  cluster_names  = module.clusters.oidc_issuer_url
}

module "grafana_fedcred" {
  for_each       = module.clusters.oidc_issuer_url
  source         = "../../../modules/app_application_federated_credentials"
  application_id = data.azuread_application.grafana.id
  display_name   = each.key
  issuer         = each.value
  subject        = "system:serviceaccount:monitor:grafana"
}