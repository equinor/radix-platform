data "azurerm_user_assigned_identity" "log-api-mi" {
  resource_group_name = module.config.common_resource_group
  name                = module.config.radix_log_api_mi_name
}

resource "azurerm_federated_identity_credential" "log-api-mi-prod" {
  for_each = module.clusters.oidc_issuer_url

  audience            = ["api://AzureADTokenExchange"]
  name                = "k8s-radix-log-api-prod-${each.key}-${module.config.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:radix-log-api-prod:server-sa"
  parent_id           = data.azurerm_user_assigned_identity.log-api-mi.id
  resource_group_name = data.azurerm_user_assigned_identity.log-api-mi.resource_group_name
}
resource "azurerm_federated_identity_credential" "log-api-mi-qa" {
  for_each = module.clusters.oidc_issuer_url

  audience            = ["api://AzureADTokenExchange"]
  name                = "k8s-radix-log-api-qa-${each.key}-${module.config.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:radix-log-api-api-qa:server-sa"
  parent_id           = data.azurerm_user_assigned_identity.log-api-mi.id
  resource_group_name = data.azurerm_user_assigned_identity.log-api-mi.resource_group_name
}
