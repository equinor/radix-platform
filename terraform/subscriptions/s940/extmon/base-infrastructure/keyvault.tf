module "keyvault_logicapp_identity" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-logicapp-keyvault-${module.config.environment}"
  location            = module.config.location
  resource_group_name = module.config.common_resource_group

  roleassignments       = {}
  federated_credentials = {}

  tags = {
    IaC = "terraform"
  }
}

module "keyvault" {
  source                                      = "../../../modules/key-vault"
  location                                    = module.config.location
  vault_name                                  = "radix-keyv-${module.config.environment}"
  resource_group_name                         = module.config.common_resource_group
  vnet_resource_group                         = module.config.vnet_resource_group
  logic_app_managed_identity                  = module.keyvault_logicapp_identity.data
  environment                                 = module.config.environment
  subscription_contributor                   = module.config.subscription_contributor
}

output "keyvault_name" {
  value = module.keyvault.vault_name
}

output "keyvault_config_name" {
  value = module.keyvault.config_keyvault_name
}

output "logicapp_identity_client_id" {
  description = "Client ID for Logic App to use with Key Vault"
  value       = module.keyvault_logicapp_identity.client-id
}

output "logicapp_identity_principal_id" {
  description = "Principal ID of Logic App managed identity"
  value       = module.keyvault_logicapp_identity.principal_id
}

output "keyvault_uri" {
  description = "URI of Key Vault for Logic App to access"
  value       = module.keyvault.vault_uri
}