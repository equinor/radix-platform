resource "azuread_application_registration" "this" {
  display_name                       = var.displayname
  sign_in_audience                   = "AzureADMyOrg"
  service_management_reference       = var.service_management_reference
  notes                              = var.internal_notes
  requested_access_token_version     = 1
  implicit_id_token_issuance_enabled = var.implicit_id_token_issuance_enabled
}

resource "azuread_application_owner" "this" {
  for_each        = toset(var.radixowners)
  application_id  = azuread_application_registration.this.id
  owner_object_id = each.value
}

resource "azuread_application_api_access" "this" {
  for_each       = var.permissions
  application_id = azuread_application_registration.this.id
  api_client_id  = each.value.id
  scope_ids      = each.value.scope_ids
}

resource "azuread_service_principal" "this" {
  client_id                    = azuread_application_registration.this.client_id
  app_role_assignment_required = var.app_role_assignment_required
  owners                       = toset(var.radixowners)
}

output "azuread_service_principal_id" {
  value = resource.azuread_service_principal.this.id
}