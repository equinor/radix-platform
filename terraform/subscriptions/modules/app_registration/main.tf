resource "azuread_application" "this" {
  display_name                 = var.display_name
  owners                       = var.owners
  tags                         = ["iac=terraform"]
  service_management_reference = var.service_id
  lifecycle {
    ignore_changes = [required_resource_access, api, identifier_uris, web[0].homepage_url, notes]
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
}
