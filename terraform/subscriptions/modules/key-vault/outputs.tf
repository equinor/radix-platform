output "vault_id" {
  description = "The ID of this Key vault."
  # value       = azurerm_key_vault.this.id
  value       = module.kv
}

# output "vault_name" {
#   description = "The name of this Key vault."
#   value       = azurerm_key_vault.this.name
# }

# output "vault_uri" {
#   description = "The URI of this Key vault."
#   value       = azurerm_key_vault.this.vault_uri
# }
