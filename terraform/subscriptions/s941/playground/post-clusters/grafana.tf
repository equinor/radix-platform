locals {
  grafana_uris = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://grafana.${k}.${module.config.environment}.radix.equinor.com/login/generic_oauth"
  ]
}

module "grafana" {
  source       = "../../../modules/app_registration"
  display_name = "radix-ar-grafana-${module.config.environment}"
  notes        = "Grafana Oauth, main app for user authentication to Grafana"
  service_id   = "110327"
  web_uris     = concat(["https://grafana.${module.config.environment}.radix.equinor.com/login/generic_oauth"], local.grafana_uris)
  owners       = data.azuread_group.radix.members
}

data "azurerm_user_assigned_identity" "grafana" {
  resource_group_name = "monitoring"
  name                = "radix-id-grafana-admin-${module.config.environment}"
}

resource "azurerm_federated_identity_credential" "grafana-mi-fedcred" {
  for_each = module.clusters.oidc_issuer_url

  audience            = ["api://AzureADTokenExchange"]
  name                = "k8s-grafana-${each.key}"
  issuer              = each.value
  subject             = "system:serviceaccount:monitor:grafana"
  parent_id           = data.azurerm_user_assigned_identity.grafana.id
  resource_group_name = data.azurerm_user_assigned_identity.grafana.resource_group_name
}
