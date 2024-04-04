output "data" {
  description = "userassignedidentity"
  value       = azurerm_user_assigned_identity.userassignedidentity
}

output "client-id" {
  description = "userassignedidentity"
  value       = azurerm_user_assigned_identity.userassignedidentity.client_id
}
output "name" {
  description = "Name of the new user assigned identity"
  value       = azurerm_user_assigned_identity.userassignedidentity.name
}
output "principal_id" {
  value = azurerm_user_assigned_identity.userassignedidentity.principal_id
}
