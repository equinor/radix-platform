
### Vulnerability Scanner - Writer
data "azurerm_user_assigned_identity" "cost-allocation-writer" {
  resource_group_name = "cost-allocation-${prefix}{module.config.environment}"
  name                = "radix-id-cost-allocation-writer-${prefix}{module.config.environment}"
}

module "cost-allocation-writer" {
  source              = "../../../modules/federated-credentials"
  for_each            = module.clusters.oidc_issuer_url
  name                = "k8s-radix-cost-allocation-writer-${prefix}{each.key}-${prefix}{module.config.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:radix-cost-allocation:radix-cost-allocation"
  parent_id           = data.azurerm_user_assigned_identity.cost-allocation-writer.id
  resource_group_name = data.azurerm_user_assigned_identity.cost-allocation-writer.resource_group_name
  depends_on          = [module.aks]
}

### Vulnerability Scanner API - Reader
data "azurerm_user_assigned_identity" "cost-allocation-api-reader" {
  resource_group_name = "cost-allocation-${prefix}{module.config.environment}"
  name                = "radix-id-cost-allocation-reader-${prefix}{module.config.environment}"
}

module "cost-allocation-api-reader-prod" {
  source              = "../../../modules/federated-credentials"
  for_each            = module.clusters.oidc_issuer_url
  name                = "k8s-radix-cost-allocation-reader-prod-${prefix}{each.key}"
  issuer              = each.value
  subject             = "system:serviceaccount:radix-cost-allocation-api-prod:server-sa"
  parent_id           = data.azurerm_user_assigned_identity.cost-allocation-api-reader.id
  resource_group_name = data.azurerm_user_assigned_identity.cost-allocation-api-reader.resource_group_name
  depends_on          = [module.aks]
}

module "cost-allocation-api-reader-qa" {
  source              = "../../../modules/federated-credentials"
  for_each            = module.clusters.oidc_issuer_url
  name                = "k8s-radix-cost-allocation-reader-qa-${prefix}{each.key}"
  issuer              = each.value
  subject             = "system:serviceaccount:radix-cost-allocation-api-qa:server-sa"
  parent_id           = data.azurerm_user_assigned_identity.cost-allocation-api-reader.id
  resource_group_name = data.azurerm_user_assigned_identity.cost-allocation-api-reader.resource_group_name
  depends_on          = [module.aks]
}
