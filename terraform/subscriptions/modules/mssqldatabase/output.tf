output "admin_adgroup" {
  description = "Admin AD Group Display Name"
  value       = data.azuread_group.developers.display_name
}
