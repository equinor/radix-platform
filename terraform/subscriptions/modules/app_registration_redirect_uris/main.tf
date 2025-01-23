resource "azuread_application_redirect_uris" "this" {
  application_id = var.application_id
  type           = var.type
  redirect_uris  = var.redirect_uris
}
