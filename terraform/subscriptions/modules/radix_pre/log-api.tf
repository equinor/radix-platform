data "azurerm_user_assigned_identity" "log-api-mi" {
  resource_group_name = var.common_resource_group
  name                = "radix-id-log-api-${var.environment}"
}

module "log-api-mi-prod" {
  source              = "../../modules/federated-credentials"
  for_each            = module.clusters.oidc_issuer_url
  name                = "k8s-radix-log-api-prod-${each.key}-${var.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:radix-log-api-prod:server-sa"
  parent_id           = data.azurerm_user_assigned_identity.log-api-mi.id
  resource_group_name = data.azurerm_user_assigned_identity.log-api-mi.resource_group_name
  depends_on          = [module.aks]
}

module "log-api-mi-qa" {
  source              = "../../modules/federated-credentials"
  for_each            = module.clusters.oidc_issuer_url
  name                = "k8s-radix-log-api-qa-${each.key}-${var.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:radix-log-api-qa:server-sa"
  parent_id           = data.azurerm_user_assigned_identity.log-api-mi.id
  resource_group_name = data.azurerm_user_assigned_identity.log-api-mi.resource_group_name
  depends_on          = [module.aks]
}
