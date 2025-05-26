
data "azurerm_resource_group" "source_resourcegroup_common" {
  name = "common-${sourcezone}"
}

data "azurerm_key_vault" "keyvault" {
  name                = "radix-keyv-${sourcezone}" # template
  resource_group_name = data.azurerm_resource_group.source_resourcegroup_common.name
}

data "azurerm_key_vault_secret" "api_ip" {
  name         = "kubernetes-api-auth-ip-range"
  key_vault_id = data.azurerm_key_vault.keyvault.id
}

data "azurerm_storage_account" "this" {
  name                = "radixlog${prefix}{module.config.environment}"
  resource_group_name = module.config.common_resource_group
}

# data "azurerm_container_registry" "acr" {
#   for_each            = toset(["radix${sourcezone}app", "radix${sourcezone}cache", "radix${sourcezone}prod"]) # template
#   name                = each.value
#   resource_group_name = data.azurerm_resource_group.source_resourcegroup_common.name
# }

# data "azurerm_storage_account" "velero" {
#   name                = "radixvelero${sourcezone}" # template
#   resource_group_name = data.azurerm_resource_group.source_resourcegroup_common.name
# }

