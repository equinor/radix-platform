data "azurerm_user_assigned_identity" "grafana" {
  resource_group_name = "monitoring"
  name                = "radix-id-grafana-admin-${module.config.environment}"
}

module "grafana-mi-fedcred" {
  source              = "../../../modules/federated-credentials"
  for_each            = module.clusters.oidc_issuer_url
  name                = "k8s-grafana-${each.key}"
  issuer              = each.value
  subject             = "system:serviceaccount:monitor:grafana"
  parent_id           = data.azurerm_user_assigned_identity.grafana.id
  resource_group_name = data.azurerm_user_assigned_identity.grafana.resource_group_name
  depends_on          = [module.aks]
}
