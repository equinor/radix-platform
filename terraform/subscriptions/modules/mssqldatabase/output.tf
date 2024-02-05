output "admin_adgroup" {
  description = "Admin AD Group Display Name"
  value       = data.azuread_group.admin.display_name
}
