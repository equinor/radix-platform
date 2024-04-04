data "azurerm_user_assigned_identity" "azure-service-operator" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-azure-service-operator-${module.config.environment}"
}

resource "azurerm_federated_identity_credential" "azure-service-operator-fedcred" {
  for_each = module.clusters.oidc_issuer_url

  audience            = ["api://AzureADTokenExchange"]
  name                = "k8s-azure-service-operator-${each.key}-${module.config.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:azure-service-operator-system:azureserviceoperator-default"
  parent_id           = data.azurerm_user_assigned_identity.azure-service-operator.id
  resource_group_name = data.azurerm_user_assigned_identity.azure-service-operator.resource_group_name
}
