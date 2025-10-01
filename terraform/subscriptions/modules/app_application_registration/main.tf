resource "azuread_application_registration" "this" {
  display_name                       = var.displayname
  sign_in_audience                   = var.audience
  service_management_reference       = var.service_management_reference
  notes                              = var.internal_notes
  requested_access_token_version     = var.token_version
  implicit_id_token_issuance_enabled = var.implicit_id_token_issuance_enabled
}

resource "azuread_application_app_role" "this" {
  for_each             = var.app_roles
  display_name         = each.value.Displayname
  description          = each.value.Description
  application_id       = azuread_application_registration.this.id
  allowed_member_types = [each.value.Membertype]
  role_id              = uuidv5("dns", each.key)
  value                = each.value.Value
}

resource "azuread_app_role_assignment" "this" {
  for_each            = var.role_assignments
  principal_object_id = each.value.principal_object_id
  resource_object_id  = azuread_service_principal.this.id
  app_role_id         = azuread_application_app_role.this[each.value.role_key].role_id
}


resource "azuread_application_owner" "this" {
  for_each        = toset(var.radixowners)
  application_id  = azuread_application_registration.this.id
  owner_object_id = each.value
}

resource "azuread_application_optional_claims" "this" {
  count = length(var.optional_id_token_claims) > 0 ? 1 : 0
  application_id = azuread_application_registration.this.id
  dynamic "id_token" {
    for_each = toset(var.optional_id_token_claims)
    content {
      name = id_token.value
    }
  }
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

output "azuread_application_id" {
  value = resource.azuread_application_registration.this.id
}

output "azuread_application_client_id" {
  value = resource.azuread_application_registration.this.client_id
}