#region Data Sources - Subscriptions
data "azurerm_subscription" "current" {
}

data "azurerm_subscription" "subscriptions" {
  for_each = var.subscriptions

  subscription_id = each.value
}
#endregion Data Sources - Subscriptions

#region Data Sources - Azure AD Groups
data "azuread_group" "radix" {
  display_name = "Radix Privileged Accounts"
}

data "azuread_group" "s940_contributors" {
  display_name     = "AZAPPL S940 - Contributor"
  security_enabled = true
}

data "azuread_group" "s941_contributors" {
  display_name     = "AZAPPL S941 - Contributor"
  security_enabled = true
}
#endregion Data Sources - Azure AD Groups

#region Role Assignments
resource "azurerm_role_assignment" "operator-roles" {
  for_each = var.operator-roles

  principal_id         = data.azuread_group.s940_contributors.object_id
  role_definition_name = each.value.role
  scope                = data.azurerm_subscription.subscriptions[each.value.subscription].id
}

resource "azurerm_role_assignment" "developer-roles" {
  for_each = var.developer-roles

  principal_id         = data.azuread_group.s941_contributors.object_id
  role_definition_name = each.value.role
  scope                = data.azurerm_subscription.subscriptions[each.value.subscription].id
}
#endregion Role Assignments

#region Application Registrations
resource "azuread_application_registration" "ar-radix-servicenow-proxy-client" {
  display_name                 = "ar-radix-servicenow-proxy-client"
  service_management_reference = "110327"
}

#TODO - Need refinement
resource "azuread_application" "ar-radix-servicenow-proxy-server" {
  display_name                 = "ar-radix-servicenow-proxy-server"
  owners                       = tolist(data.azuread_group.radix.members)
  service_management_reference = "110327"
  sign_in_audience             = "AzureADandPersonalMicrosoftAccount"

  identifier_uris = [
    "api://1b4a22f1-d4a1-4b6a-81b2-fd936daf1786"
  ]

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      admin_consent_description  = "Allows the app to read ServiceNow applications"
      admin_consent_display_name = "Read applications from ServiceNow"
      enabled                    = true
      id                         = "4781537a-ed53-49fd-876b-32c274831456"
      type                       = "User"
      user_consent_description   = "Allows the app to read ServiceNow applications"
      user_consent_display_name  = "Read ServiceNow applications"
      value                      = "Application.Read"
    }
  }

  single_page_application {
    redirect_uris = [
      "http://localhost:3002/swaggerui/oauth2-redirect.html",
    ]
  }
}

module "app_application_registration" {
  source   = "../../subscriptions/modules/app_application_registration"
  for_each = var.appregistrations

  app_role_assignment_required       = each.value.app_role_assignment_required
  audience                           = each.value.sign_in_audience
  displayname                        = each.value.display_name
  implicit_id_token_issuance_enabled = each.value.implicit_id_token_issuance_enabled
  internal_notes                     = each.value.notes
  permissions                        = each.value.permissions
  radixowners                        = data.azuread_group.radix.members
  service_management_reference       = each.value.service_management_reference
  token_version                      = each.value.token_version
}
#endregion Application Registrations

#region Custom Role Definitions
resource "azurerm_role_definition" "dns_txt_contributor" {
  name        = "DNS TXT Contributor"
  scope       = data.azurerm_subscription.current.id
  description = "Can manage DNS TXT records only."

  assignable_scopes = var.all_subscriptions

  permissions {
    actions = [
      "Microsoft.Network/dnsZones/TXT/*",
      "Microsoft.Network/dnsZones/read",
      "Microsoft.Authorization/*/read",
      "Microsoft.Insights/alertRules/*",
      "Microsoft.ResourceHealth/availabilityStatuses/read",
      "Microsoft.Resources/deployments/*",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Support/*"
    ]
    not_actions = []
  }
}

resource "azurerm_role_definition" "radix_standard_reader" {
  name  = "Radix Standard Reader"
  scope = data.azurerm_subscription.current.id

  permissions {
    actions = ["*/read"]
    not_actions = [
      "Microsoft.OperationalInsights/workspaces/query/read",
      "Microsoft.OperationalInsights/workspaces/query/*/read",
      "Microsoft.OperationalInsights/workspaces/search/action"
    ]
  }

  assignable_scopes = var.all_subscriptions
}

resource "azurerm_role_definition" "radix_confidential_data_contributor" {
  name        = "Radix Confidential Data Contributor"
  scope       = data.azurerm_subscription.current.id
  description = "Role definition to access and update KV,SA and ACR"

  assignable_scopes = var.all_subscriptions

  permissions {
    actions = [
      "Microsoft.ContainerRegistry/registries/read",
      "Microsoft.ContainerRegistry/registries/artifacts/delete",
      "Microsoft.ContainerRegistry/registries/pull/read",
      "Microsoft.ContainerRegistry/registries/push/write",
      "Microsoft.KeyVault/vaults/read",
      "Microsoft.KeyVault/vaults/write",
      "Microsoft.OperationalInsights/workspaces/read",
      "Microsoft.OperationalInsights/workspaces/query/read",
      "Microsoft.OperationalInsights/workspaces/query/*/read",
      "Microsoft.OperationalInsights/workspaces/analytics/query/action",
      "Microsoft.OperationalInsights/workspaces/search/action",
      "Microsoft.Storage/storageAccounts/blobServices/containers/delete",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/write",
      "Microsoft.Storage/storageAccounts/blobServices/generateUserDelegationKey/action"
    ]
    data_actions = [
      "Microsoft.KeyVault/vaults/secrets/*",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/move/action",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action"
    ]
    not_actions = []
  }
}
#endregion Custom Role Definitions
