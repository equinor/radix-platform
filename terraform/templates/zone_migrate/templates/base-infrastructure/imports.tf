
data "azurerm_resource_group" "source_resourcegroup_common" {
  name = "common-${zone}"
}

data "azurerm_key_vault" "keyvault" {
  name                = "radix-keyv-${zone}" # template
  resource_group_name = data.azurerm_resource_group.source_resourcegroup_common.name
}

data "azurerm_key_vault_secret" "grafana_admin" {
  name         = "s940-radix-grafana-c2-prod-mysql-admin-pwd"
  key_vault_id = data.azurerm_key_vault.keyvault.id
}

data "azurerm_container_registry" "acr" {
  for_each            = toset(["radix${zone}app", "radix${zone}cache", "radix${zone}prod"]) # template
  name                = each.value
  resource_group_name = data.azurerm_resource_group.source_resourcegroup_common.name
}

data "azurerm_storage_account" "velero" {
  name                = "radixvelero${zone}" # template
  resource_group_name = data.azurerm_resource_group.source_resourcegroup_common.name
}

