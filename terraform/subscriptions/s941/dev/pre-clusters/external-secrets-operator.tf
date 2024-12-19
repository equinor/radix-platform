data "azurerm_user_assigned_identity" "this" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-external-secrets-operator-${module.config.environment}"
}

module "eso" {
  source              = "../../../modules/federated-credentials"
  for_each            = module.clusters.oidc_issuer_url
  name                = "operator-wi-${each.key}"
  issuer              = each.value
  subject             = "system:serviceaccount:external-secrets:workload-identity-sa"
  parent_id           = data.azurerm_user_assigned_identity.this.id
  resource_group_name = data.azurerm_user_assigned_identity.this.resource_group_name
  depends_on          = [module.aks]
}
