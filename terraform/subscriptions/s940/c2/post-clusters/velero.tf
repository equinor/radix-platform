data "azurerm_user_assigned_identity" "velero" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-velero-${module.config.environment}"
}

resource "azurerm_federated_identity_credential" "velero-mi-fedcred" {
  for_each = module.clusters.oidc_issuer_url

  audience            = ["api://AzureADTokenExchange"]
  name                = "k8s-velero-${each.key}-${module.config.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:velero:velero"
  parent_id           = data.azurerm_user_assigned_identity.velero.id
  resource_group_name = module.config.common_resource_group
}

resource "azurerm_storage_container" "velero" {
  for_each              = module.clusters.oidc_issuer_url
  name                  = each.key
  storage_account_name  = "radixvelero${module.config.environment}"
  container_access_type = "private" # Options: private, blob, container
}

resource "azurerm_storage_container" "velero" {
  for_each              = module.clusters.oidc_issuer_url
  name                  = each.key
  storage_account_name  = "radixvelero${module.config.environment}"
  container_access_type = "private" # Options: private, blob, container
}
