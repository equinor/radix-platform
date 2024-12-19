data "azurerm_user_assigned_identity" "cert-manager-mi" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-certmanager-${module.config.environment}"
}

module "cert-manager-mi-fedcred" {
  source              = "../../../modules/federated-credentials"
  for_each            = module.clusters.oidc_issuer_url
  name                = "k8s-cert-manager-dns01-${each.key}-${module.config.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:cert-manager:cert-manager"
  parent_id           = data.azurerm_user_assigned_identity.cert-manager-mi.id
  resource_group_name = data.azurerm_user_assigned_identity.cert-manager-mi.resource_group_name
  depends_on          = [module.aks]
}