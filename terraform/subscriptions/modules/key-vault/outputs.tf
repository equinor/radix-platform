output "vault_id" {
  description = "Azure KeyVault ID"
  value       = azurerm_key_vault.this.id
}

output "vault_name" {
  description = "The name of this Key vault."
  value       = azurerm_key_vault.this.name
}

output "config_keyvault_name" {
  value = azurerm_key_vault.config.name
}

