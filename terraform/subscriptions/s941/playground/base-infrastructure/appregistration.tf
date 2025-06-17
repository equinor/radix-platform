module "app_application_registration" {
  source                             = "../../../modules/app_application_registration"
  for_each                           = var.appregistrations
  displayname                        = each.value.display_name
  internal_notes                     = each.value.notes
  service_management_reference       = each.value.service_management_reference
  radixowners                        = data.azuread_group.radix.members
  permissions                        = each.value.permissions
  implicit_id_token_issuance_enabled = each.value.implicit_id_token_issuance_enabled
  app_role_assignment_required       = each.value.app_role_assignment_required
}

output "app_webconsole_client_id" {
  value = module.app_application_registration.webconsole.azuread_application_client_id
}
