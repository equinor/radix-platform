output "keyvault_lock_creator_role_name" {
  description = "Custom role name for other zone identities that update the Key Vault."
  value       = module.keyvault_lock_creator_role.name
}

output "radix_id_gitrunner_locker_client_id" {
  description = "Client ID used by the resource locking workflow."
  value       = module.radix_id_gitrunner_locker.client-id
}

output "keyvault_id" {
  description = "ID of the zone's main Key Vault."
  value       = module.keyvault.azurerm_key_vault_id
}

output "keyvault_name" {
  description = "Name of the zone's main Key Vault."
  value       = module.keyvault.vault_name
}

output "keyvault_config_name" {
  description = "Name of the zone's bootstrap Key Vault."
  value       = azurerm_key_vault.config.name
}

output "ampls_id" {
  description = "ID of the shared AMPLS instance, or null when disabled."
  value       = one(module.ampls[*].id)
}

output "ampls_name" {
  description = "Name of the shared AMPLS instance, or null when disabled."
  value       = one(module.ampls[*].name)
}
output "easyauth_app_client_id" {
  description = "EasyAuth app registration client ID (radix-flux EASYAUTH_ENTRA_CLIENT_ID). null when EasyAuth is disabled."
  value       = one(module.easyauth[*].app_client_id)
}

output "easyauth_dex_identity_client_id" {
  description = "Dex managed identity client ID (radix-flux EASYAUTH_DEX_MI_CLIENT_ID). null when EasyAuth is disabled."
  value       = one(module.easyauth[*].dex_identity_client_id)
}

output "easyauth_postgres_host" {
  description = "Dex Postgres server FQDN (radix-flux EASYAUTH_POSTGRES_HOST). null when EasyAuth is disabled."
  value       = one(module.easyauth[*].postgres_host)
}