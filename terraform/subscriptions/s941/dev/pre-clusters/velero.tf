data "azurerm_user_assigned_identity" "velero" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-velero-${module.config.environment}"
}

module "velero-mi-fedcred" {
  source              = "../../../modules/federated-credentials"
  for_each            = module.clusters.oidc_issuer_url
  name                = "k8s-velero-${each.key}-${module.config.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:velero:velero"
  parent_id           = data.azurerm_user_assigned_identity.velero.id
  resource_group_name = data.azurerm_user_assigned_identity.velero.resource_group_name
  depends_on          = [module.aks]
}
