# Handle Azure Monitor Data Source
resource "azuread_application" "grafana-logreader" {
  description  = "Used to read data from Log Analytics Workspace"
  display_name = "radix-ar-grafana-logreader-extmon"

  service_management_reference = var.service-manager-ref
  owners                       = data.azuread_group.radix.members
}
resource "azuread_service_principal" "grafana-logreader" {
  client_id                    = azuread_application.grafana-logreader.client_id
  app_role_assignment_required = false
  owners                       = azuread_application.grafana-logreader.owners
}

resource "azurerm_role_assignment" "grafana-logreader" {
  for_each = data.azurerm_subscription.subscriptions

  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.grafana-logreader.id
  scope                = each.value.id
}

output "ar-grafan-logreader" {
  value = {
    client-id = azuread_application.grafana-logreader.client_id,
    name      = azuread_application.grafana-logreader.display_name
  }
}
