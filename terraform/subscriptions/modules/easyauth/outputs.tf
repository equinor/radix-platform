output "app_client_id" {
  value = module.app.azuread_application_client_id
}

output "dex_identity_client_id" {
  value = module.dex_identity.client-id
}

output "postgres_host" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}
