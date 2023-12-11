resource "azuread_service_principal" "serviceprincipal" {
  application_id               = var.client_id
  app_role_assignment_required = var.app_role_assignment_required
  owners                       = var.owners
}
