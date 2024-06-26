

module "config" {
  source = "../../../modules/config"
}

module "resourcegroups" {
  for_each = toset(var.resource_groups)
  source   = "../../../modules/resourcegroups"
  name     = each.value
  location = module.config.location
}

data "azurerm_key_vault" "keyvault" {
  name                = module.config.key_vault_name
  resource_group_name = module.config.common_resource_group
}

data "azurerm_log_analytics_workspace" "workspace" {
  name                = module.config.log_analytics_name
  resource_group_name = module.config.common_resource_group
}

data "azurerm_storage_account" "velero" {
  name                = "radixvelero${module.config.environment}"
  resource_group_name = module.config.common_resource_group
}

module "radix_id_external_secrets_operator_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-external-secrets-operator-${module.config.environment}"
  location            = module.config.location
  resource_group_name = "common-${module.config.environment}"
  roleassignments = {
    kv_user = {
      role     = "Key Vault Secrets Officer"
      scope_id = data.azurerm_key_vault.keyvault.id
    }
  }
}

module "radix_id_velero_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-velero-${module.config.environment}"
  location            = module.config.location
  resource_group_name = "common-${module.config.environment}"
  roleassignments = {
    sac_user = {
      role     = "Storage Blob Data Contributor"
      scope_id = data.azurerm_storage_account.velero.id
    }
  }
}
