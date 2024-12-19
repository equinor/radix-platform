data "azurerm_user_assigned_identity" "this" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-external-secrets-operator-${module.config.environment}"
}

resource "azurerm_federated_identity_credential" "eso" {
  for_each = module.clusters.oidc_issuer_url

  audience            = ["api://AzureADTokenExchange"]
  issuer              = each.value
  name                = "operator-wi-${each.key}"
  parent_id           = data.azurerm_user_assigned_identity.this.id
  resource_group_name = module.config.common_resource_group
  subject             = "system:serviceaccount:external-secrets:workload-identity-sa"
  depends_on          = [module.aks]
}