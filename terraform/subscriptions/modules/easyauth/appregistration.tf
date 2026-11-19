module "app" {
  source = "../app_application_registration"

  displayname                  = var.app_display_name
  service_management_reference = "110327"
  homepage_url                 = "https://radix.equinor.com"
  radixowners                  = var.app_owners
  app_role_assignment_required = true
  default_access_assignments   = { for groupid in var.allowed_group_objectids : groupid => groupid }
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
        "7427e0e9-2fba-42fe-b0c0-848c9e6a8182", # offline_access (Dex refreshes the user's groups)
      ]
    }
  }
}
