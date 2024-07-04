locals {
  web-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
        "http://localhost:8080/applications",
        "http://localhost:3000/auth-callback",

        "https://console.c2.radix.equinor.com/oauth2/callback",
        "https://console.${k}.c2.radix.equinor.com/oauth2/callback",

        "https://auth-radix-web-console-prod.${k}.c2.radix.equinor.com/oauth2/callback",
        "https://auth-radix-web-console-prod.c2.radix.equinor.com/oauth2/callback",

        "https://auth-radix-web-console-qa.${k}.c2.radix.equinor.com/oauth2/callback",
        "https://auth-radix-web-console-qa.c2.radix.equinor.com/oauth2/callback",
    ]]
  ))

  singlepage-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "https://auth-radix-web-console-prod.${k}.c2.radix.equinor.com/applications",
      "https://auth-radix-web-console-qa.c2.radix.equinor.com/applications",

      "https://console.${k}.c2.radix.equinor.com/applications",
      "https://console.c2.radix.equinor.com/applications",
    ]]
  ))
}

data "azuread_application_published_app_ids" "well_known" {}
data "azuread_service_principal" "servicenow" {
  display_name = "ar-radix-servicenow-proxy-server"
}
data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}
data "azuread_service_principal" "kubernetes" {
  client_id = data.azuread_application_published_app_ids.well_known.result["AzureKubernetesServiceAadServer"]
}
module "webconsole" {
  source          = "../../../modules/app_registration"
  display_name    = "Omnia Radix Web Console - C2 Clusters"
  service_id      = "110327"
  web_uris        = local.web-uris
  singlepage_uris = local.singlepage-uris
  owners          = data.azuread_group.radix.members
  implicit_grant  = false

  resource_access = {
    servicenow = {
      app_id = data.azuread_service_principal.servicenow.client_id
      scope_ids = [
        data.azuread_service_principal.servicenow.oauth2_permission_scope_ids["Application.Read"]
      ]
    }
    kubernetes = {
      app_id = data.azuread_application_published_app_ids.well_known.result["AzureKubernetesServiceAadServer"]
      scope_ids = [
        data.azuread_service_principal.kubernetes.oauth2_permission_scope_ids["user.read"],
      ]
    }
    msgraph = {
      app_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
      scope_ids = [
        data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["GroupMember.Read.All"],
        data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["User.Read"],
      ]
    }
  }
}
