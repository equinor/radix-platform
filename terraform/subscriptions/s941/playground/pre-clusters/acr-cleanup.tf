data "azurerm_user_assigned_identity" "acr-cleanup-mi" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-acr-cleanup-${module.config.environment}"
}

module "acr-cleanup-mi-fedcred" {
  source              = "../../../modules/federated-credentials"
  for_each            = module.clusters.oidc_issuer_url
  name                = "k8s-acr-cleanup-${each.key}-${module.config.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:radix-acr-cleanup:radix-acr-cleanup"
  parent_id           = data.azurerm_user_assigned_identity.acr-cleanup-mi.id
  resource_group_name = data.azurerm_user_assigned_identity.acr-cleanup-mi.resource_group_name
  depends_on          = [module.aks]
}
