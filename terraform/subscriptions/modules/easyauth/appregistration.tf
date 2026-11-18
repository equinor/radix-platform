data "azuread_group" "allowed" {
  for_each         = toset(var.allowed_group_names)
  display_name     = each.value
  security_enabled = true
}

module "app" {
  source = "../app_application_registration"

  displayname                  = var.app_display_name
  service_management_reference = "110327"
  radixowners                  = var.app_owners
  app_role_assignment_required = true
  default_access_assignments   = { for name, group in data.azuread_group.allowed : name => group.object_id }
  group_membership_claims      = ["All"]
  optional_id_token_claims     = ["groups"]
  optional_access_token_claims = ["groups"]
  optional_saml2_token_claims  = ["groups"]
  permissions = {
    msgraph = {
      id = "00000003-0000-0000-c000-000000000000" # msgraph
      scope_ids = [
        "06da0dbc-49e2-44d2-8312-53f166ab848a", # Directory.Read.All (Dex resolves group membership, requires admin consent)
        "e1fe6dd8-ba31-4d61-89e7-88639da4683d", # User.Read
        "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0", # email
        "7427e0e9-2fba-42fe-b0c0-848c9e6a8182", # offline_access
        "37f7f235-527c-4136-accd-4a02d197296e", # openid
        "14dad69e-099b-42c9-810b-d002981feec1", # profile
      ]
    }
  }
}
