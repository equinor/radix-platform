output "admin_adgroup" {
  description = "Admin AD Group Display Name"
  value       = data.azuread_group.admin.display_name
}

output "mi-admin" {
  value = {
    name = azurerm_user_assigned_identity.admin.name
    client_id = azurerm_user_assigned_identity.admin.client_id
  }
}
