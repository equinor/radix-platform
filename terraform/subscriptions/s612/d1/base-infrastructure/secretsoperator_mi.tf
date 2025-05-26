module "radix_id_external_secrets_operator_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-external-secrets-operator-${module.config.environment}"
  location            = module.config.location
  resource_group_name = module.resourcegroup_common.data.name
  roleassignments = {
    kv_user = {
      role     = "Key Vault Secrets Officer"
      scope_id = module.keyvault.azurerm_key_vault_id
    }
  }
}