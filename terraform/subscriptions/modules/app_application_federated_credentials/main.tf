resource "azuread_application_federated_identity_credential" "this" {
  application_id = var.application_id
  display_name   = var.display_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.issuer
  subject        = var.subject
}
