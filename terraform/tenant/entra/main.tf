data "azurerm_subscription" "current" {
}

data "azuread_group" "radix" {
  display_name = "Radix"
}

data "azuread_group" "radix-platform-developers" {
  display_name     = "Radix Platform Developers"
  security_enabled = true
}

data "azuread_group" "radix-platform-operators" {
  display_name     = "Radix Platform Operators"
  security_enabled = true
}
data "azurerm_subscription" "subscriptions" {
  for_each        = var.subscriptions
  subscription_id = each.value
}

resource "azurerm_role_assignment" "operator-roles" {
  for_each = var.operator-roles

  principal_id         = data.azuread_group.radix-platform-operators.id
  scope                = data.azurerm_subscription.subscriptions[each.value.subscription].id
  role_definition_name = each.value.role
}
resource "azurerm_role_assignment" "developer-roles" {
  for_each = var.developer-roles

  principal_id         = data.azuread_group.radix-platform-developers.id
  scope                = data.azurerm_subscription.subscriptions[each.value.subscription].id
  role_definition_name = each.value.role
}

resource "azuread_application_registration" "ar-radix-servicenow-proxy-client" {
  display_name                 = "ar-radix-servicenow-proxy-client"
  service_management_reference = "110327"
}

#TODO - Need refinement
resource "azuread_application" "ar-radix-servicenow-proxy-server" {
  display_name = "ar-radix-servicenow-proxy-server"
  identifier_uris = [
    "api://1b4a22f1-d4a1-4b6a-81b2-fd936daf1786"
  ]
  owners                       = tolist(data.azuread_group.radix.members)
  service_management_reference = "110327"
  sign_in_audience             = "AzureADandPersonalMicrosoftAccount"

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

resource "azurerm_role_definition" "dns_txt_contributor" {
  name        = "DNS TXT Contributor"
  description = "Can manage DNS TXT records only."
  scope       = data.azurerm_subscription.current.id
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
  assignable_scopes = var.all_subscriptions
}

module "app_application_registration" {
  source                             = "../../subscriptions/modules/app_application_registration"
  for_each                           = var.appregistrations
  displayname                        = each.value.display_name
  internal_notes                     = each.value.notes
  service_management_reference       = each.value.service_management_reference
  radixowners                        = data.azuread_group.radix.members
  permissions                        = each.value.permissions
  implicit_id_token_issuance_enabled = each.value.implicit_id_token_issuance_enabled
  app_role_assignment_required       = each.value.app_role_assignment_required
  audience                           = each.value.sign_in_audience
  token_version                      = each.value.token_version
}
