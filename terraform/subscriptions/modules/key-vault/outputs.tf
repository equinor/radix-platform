output "vault_id" {
  description = "Azure KeyVault ID"
  value       = azurerm_key_vault.this.id
}

# output "data" {
#   description = "The ID of this Key vault."
#   # value       = azurerm_key_vault.this.id
#   value = {
#     "vault_id" = module.kv.vault_id
#   }
# }

# output "name" {

# }

# output "vault_name" {
#   description = "The name of this Key vault."
#   value       = azurerm_key_vault.this.name
# }

# output "vault_uri" {
#   description = "The URI of this Key vault."
#   value       = azurerm_key_vault.this.vault_uri
# }
