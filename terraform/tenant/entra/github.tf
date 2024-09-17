

resource "azuread_application" "APP_GITHUB_ACTION_CLUSTER_S941" {
  display_name                 = "ar-radix-platform-github-dev-cluster-maintenance"
  owners                       = data.azuread_group.radix.members
  sign_in_audience             = "AzureADandPersonalMicrosoftAccount"
  service_management_reference = "110327"
  tags                         = ["iac=terraform"]

  api {
    known_client_applications      = []
    mapped_claims_enabled          = false
    requested_access_token_version = 2
  }
}
resource "azuread_service_principal" "SP_GITHUB_ACTION_CLUSTER_S941" {
  client_id                    = azuread_application.APP_GITHUB_ACTION_CLUSTER_S941.client_id
  app_role_assignment_required = false
  owners                       = azuread_application.APP_GITHUB_ACTION_CLUSTER_S941.owners
}

resource "azuread_application" "APP_GITHUB_ACTION_CLUSTER_S940" {
  display_name                 = "OP-Terraform-Github Action"
  owners                       = data.azuread_group.radix-platform-operators.members
  sign_in_audience             = "AzureADMyOrg"
  tags                         = ["iac=terraform"]
  service_management_reference = "110327"
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000"
    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
      type = "Scope"
    }
  }

  api {
    known_client_applications      = []
    mapped_claims_enabled          = false
    requested_access_token_version = 1
  }
}
resource "azuread_service_principal" "SP_GITHUB_ACTION_CLUSTER_S940" {
  client_id                    = azuread_application.APP_GITHUB_ACTION_CLUSTER_S940.client_id
  app_role_assignment_required = false
  owners                       = azuread_application.APP_GITHUB_ACTION_CLUSTER_S940.owners
}

output "s941-github-operator-client-id" {
  value = {
    client-id = azuread_application.APP_GITHUB_ACTION_CLUSTER_S941.client_id
    name      = azuread_application.APP_GITHUB_ACTION_CLUSTER_S941.display_name
  }
}
output "s940-github-operator-client-id" {
  value = {
    client-id = azuread_application.APP_GITHUB_ACTION_CLUSTER_S940.client_id
    name      = azuread_application.APP_GITHUB_ACTION_CLUSTER_S940.display_name
  }
}
