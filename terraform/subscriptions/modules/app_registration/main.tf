resource "azuread_application" "this" {
  display_name                 = var.display_name
  owners                       = var.owners
  tags                         = ["iac=terraform"]
  service_management_reference = var.service_id

  lifecycle {
    ignore_changes = [single_page_application, web, identifier_uris, api, notes, required_resource_access]
  }

  api {
    known_client_applications      = []
    mapped_claims_enabled          = false
    requested_access_token_version = 1
  }

  dynamic "required_resource_access" {
    for_each = var.required_resource_access
    content {
      resource_app_id = required_resource_access.value.resource_app_id
      dynamic "resource_access" {
        for_each = required_resource_access.value.resource_access
        content {
          id   = resource_access.value.id
          type = resource_access.value.type
        }
      }
    }
  }
}

resource "azuread_application_identifier_uri" "this" {
  for_each       = var.expose_API ? { "${var.display_name}" : true } : {}
  application_id = azuread_application.this.id
  identifier_uri = "api://${azuread_application.this.client_id}"
  depends_on     = [azuread_service_principal.this]
}


resource "azuread_application_api_access" "app" {
  for_each       = var.resource_access
  api_client_id  = each.value.app_id
  application_id = azuread_application.this.id
  scope_ids      = each.value.scope_ids
}

resource "azuread_service_principal" "this" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = var.assignment_required
  owners                       = var.owners
}

output "azuread_service_principal_id" {
  value = resource.azuread_service_principal.this.id
}
