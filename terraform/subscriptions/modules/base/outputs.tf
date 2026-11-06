output "keyvault_lock_creator_role_name" {
  description = "Custom role name for other zone identities that update the Key Vault."
  value       = module.keyvault_lock_creator_role.name
}

output "radix_id_gitrunner_locker_client_id" {
  description = "Client ID used by the resource locking workflow."
  value       = module.radix_id_gitrunner_locker.client-id
}