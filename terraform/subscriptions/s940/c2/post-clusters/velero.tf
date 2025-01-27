resource "azurerm_storage_container" "velero" {
  for_each              = module.clusters.oidc_issuer_url
  name                  = each.key
  storage_account_name  = "radixvelero${module.config.environment}"
  container_access_type = "private" # Options: private, blob, container
}
