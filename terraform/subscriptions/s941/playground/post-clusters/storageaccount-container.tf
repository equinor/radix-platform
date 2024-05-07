data "azurerm_storage_account" "this" {
  name                = "radixvelero${module.config.environment}"
  resource_group_name = module.config.common_resource_group
}

resource "azurerm_storage_container" "this" {
  for_each              = module.clusters.oidc_issuer_url
  name                  = each.key
  storage_account_name  = data.azurerm_storage_account.this.name
  container_access_type = "private"
  lifecycle {
    prevent_destroy = true
  }
}