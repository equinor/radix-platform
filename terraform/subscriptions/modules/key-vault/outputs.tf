output "vault_id" {
  description = "Azure KeyVault ID"
  value       = azurerm_key_vault.this.id
}

output "vault_name" {
  description = "The name of this Key vault."
  value       = azurerm_key_vault.this.name
}

output "vault_uri" {
  description = "The URI of this Key vault."
  value       = azurerm_key_vault.this.vault_uri
}

output "logic_app_identity_client_id" {
  description = "Client ID of the managed identity for Logic App to use with Key Vault"
  value       = var.logic_app_managed_identity.client_id
}

output "logic_app_identity_id" {
  description = "Resource ID of the managed identity for Logic App"
  value       = var.logic_app_managed_identity.id
}

# output "vault_uri" {
#   description = "The URI of this Key vault."
#   value       = azurerm_key_vault.this.vault_uri
# }
