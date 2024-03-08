output "data" {
  description = "userassignedidentity"
  value       = azurerm_user_assigned_identity.userassignedidentity
}

output "client-id" {
  description = "userassignedidentity"
  value       = azurerm_user_assigned_identity.userassignedidentity.client_id
}
