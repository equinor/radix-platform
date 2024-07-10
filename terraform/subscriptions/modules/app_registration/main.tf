resource "azuread_application" "this" {
  display_name                 = var.display_name
  owners                       = var.owners
  tags                         = ["iac=terraform"]
  service_management_reference = var.service_id

  lifecycle {
    ignore_changes = [required_resource_access, api, identifier_uris, web[0].homepage_url, notes]
  }

  api {
    known_client_applications      = []
    mapped_claims_enabled          = false
    requested_access_token_version = 1
  }

  web {
    redirect_uris = var.web_uris
    dynamic "implicit_grant" {
      for_each = var.implicit_grant ? [1] : []
      content {
        access_token_issuance_enabled = true
        id_token_issuance_enabled     = true
      }
    }
  }
  single_page_application {
    redirect_uris = var.singlepage_uris
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

resource "azuread_application_api_access" "app" {
  for_each = var.resource_access

  api_client_id  = each.value.app_id
  application_id = azuread_application.this.id

  scope_ids = each.value.scope_ids
}

resource "azuread_service_principal" "this" {
  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = var.assignment_required
  owners                       = var.owners
}
