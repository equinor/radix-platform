output "id" {
  description = "The ID of the custom role definition."
  value       = azurerm_role_definition.this.role_definition_id
}

output "name" {
  description = "The name of the custom role definition."
  value       = azurerm_role_definition.this.name
}