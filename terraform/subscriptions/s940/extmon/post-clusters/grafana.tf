data "azuread_application" "grafana-logreader" {
  display_name = module.config.grafana_ar_reader_display_name
}

resource "azuread_application_federated_identity_credential" "grafana-logreader" {
  for_each = module.clusters.oidc_issuer_url

  audiences      = ["api://AzureADTokenExchange"]
  display_name   = "k8s-radix-grafana-logreader-${each.key}"
  issuer         = each.value
  subject        = "system:serviceaccount:monitor:grafana"
  application_id = data.azuread_application.grafana-logreader.id
}
