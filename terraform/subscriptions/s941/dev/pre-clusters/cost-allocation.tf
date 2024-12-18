
### Vulnerability Scanner - Writer
data "azurerm_user_assigned_identity" "cost-allocation-writer" {
  resource_group_name = "cost-allocation-${module.config.environment}"
  name                = "radix-id-cost-allocation-writer-${module.config.environment}"
}

resource "azurerm_federated_identity_credential" "cost-allocation-writer" {
  for_each = module.clusters.oidc_issuer_url

  audience            = ["api://AzureADTokenExchange"]
  name                = "k8s-radix-cost-allocation-writer-${each.key}-${module.config.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:radix-cost-allocation:radix-cost-allocation"
  parent_id           = data.azurerm_user_assigned_identity.cost-allocation-writer.id
  resource_group_name = data.azurerm_user_assigned_identity.cost-allocation-writer.resource_group_name
  depends_on          = [module.aks]
}

### Vulnerability Scanner API - Reader
data "azurerm_user_assigned_identity" "cost-allocation-api-reader" {
  resource_group_name = "cost-allocation-${module.config.environment}"
  name                = "radix-id-cost-allocation-reader-${module.config.environment}"
}

resource "azurerm_federated_identity_credential" "cost-allocation-api-reader-prod" {
  for_each = module.clusters.oidc_issuer_url

  audience            = ["api://AzureADTokenExchange"]
  name                = "k8s-radix-cost-allocation-reader-prod-${each.key}-${module.config.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:radix-cost-allocation-api-prod:server-sa"
  parent_id           = data.azurerm_user_assigned_identity.cost-allocation-api-reader.id
  resource_group_name = data.azurerm_user_assigned_identity.cost-allocation-api-reader.resource_group_name
  depends_on          = [module.aks]
}
resource "azurerm_federated_identity_credential" "cost-allocation-api-reader-qa" {
  for_each = module.clusters.oidc_issuer_url

  audience            = ["api://AzureADTokenExchange"]
  name                = "k8s-radix-cost-allocation-reader-qa-${each.key}-${module.config.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:radix-cost-allocation-api-qa:server-sa"
  parent_id           = data.azurerm_user_assigned_identity.cost-allocation-api-reader.id
  resource_group_name = data.azurerm_user_assigned_identity.cost-allocation-api-reader.resource_group_name
  depends_on          = [module.aks]
}

