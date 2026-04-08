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

module "appreg_servicenow_client" {
  source = "../../subscriptions/modules/app_application_registration"

  displayname    = "ar-radix-servicenow-proxy-client"
  internal_notes = null
  permissions = {
    msgraph = {
      id = "00000003-0000-0000-c000-000000000000" # msgraph
      scope_ids = [
        "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      ]
    }
  }
  radixowners                  = data.azuread_group.radix.members
  service_management_reference = "110327"
  token_version                = 2
}

module "app_application_registration_swaggerui" {
  source = "../../subscriptions/modules/app_application_registration"

  displayname    = "radix-ar-swaggerui"
  internal_notes = null
  permissions = {
    msgraph = {
      id = "00000003-0000-0000-c000-000000000000" # msgraph
      scope_ids = [
        "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      ]
    }
    kubernetes = {
      id = "6dae42f8-4368-4678-94ff-3960e28e3630" # kubernetes
      scope_ids = [
        "34a47c2f-cd0d-47b4-a93c-2c41130c671c" # user.read
      ]
    }
  }

  radixowners                  = data.azuread_group.radix.members
  service_management_reference = "110327"
  token_version                = 2
}

resource "azuread_application_redirect_uris" "swaggerui" {
  application_id = module.app_application_registration_swaggerui.azuread_application_id
  type           = "SPA"

  redirect_uris = [
    "http://localhost:3000/swaggerui/oauth2-redirect.html",
    "http://localhost:3001/swaggerui/oauth2-redirect.html",
    "http://localhost:3002/swaggerui/oauth2-redirect.html",
    "http://localhost:3003/swaggerui/oauth2-redirect.html",

    # radix-api (component: server, dnsAlias: api)
    "https://api.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://api.c2.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://api.c3.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://api.dev.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://api.playground.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-api-qa.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-api-prod.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-api-qa.c2.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-api-prod.c2.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-api-qa.c3.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-api-prod.c3.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-api-qa.dev.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-api-prod.dev.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-api-qa.playground.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-api-prod.playground.radix.equinor.com/swaggerui/oauth2-redirect.html",

    # radix-cost-allocation-api (component: server, dnsAlias: cost-api)
    "https://cost-api.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://cost-api.c2.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://cost-api.c3.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://cost-api.dev.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://cost-api.playground.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-cost-allocation-api-qa.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-cost-allocation-api-prod.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-cost-allocation-api-qa.c2.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-cost-allocation-api-prod.c2.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-cost-allocation-api-qa.c3.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-cost-allocation-api-prod.c3.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-cost-allocation-api-qa.dev.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-cost-allocation-api-prod.dev.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-cost-allocation-api-qa.playground.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-cost-allocation-api-prod.playground.radix.equinor.com/swaggerui/oauth2-redirect.html",

    # radix-vulnerability-scanner-api (component: server, dnsAlias: vulnerability-scan-api)
    "https://vulnerability-scan-api.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://vulnerability-scan-api.c2.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://vulnerability-scan-api.c3.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://vulnerability-scan-api.dev.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://vulnerability-scan-api.playground.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-vulnerability-scanner-api-qa.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-vulnerability-scanner-api-prod.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-vulnerability-scanner-api-qa.c2.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-vulnerability-scanner-api-prod.c2.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-vulnerability-scanner-api-qa.c3.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-vulnerability-scanner-api-prod.c3.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-vulnerability-scanner-api-qa.dev.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-vulnerability-scanner-api-prod.dev.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-vulnerability-scanner-api-qa.playground.radix.equinor.com/swaggerui/oauth2-redirect.html",
    "https://server-radix-vulnerability-scanner-api-prod.playground.radix.equinor.com/swaggerui/oauth2-redirect.html",
  ]
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
