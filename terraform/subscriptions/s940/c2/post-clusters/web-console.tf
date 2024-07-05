locals {
  environment = "prod"
  web-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
        "http://localhost:3000/auth-callback",

        "https://console.radix.equinor.com/oauth2/callback",
        "https://console.${module.config.environment}.radix.equinor.com/oauth2/callback",
        "https://console.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",

        "https://auth-radix-web-console-${local.environment}.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",
        "https://auth-radix-web-console-${local.environment}.${module.config.environment}.radix.equinor.com/oauth2/callback",
        "https://auth-radix-web-console-${local.environment}.radix.equinor.com/oauth2/callback",
    ]]
  ))

  singlepage-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:8080/applications",

      "https://auth-radix-web-console-${local.environment}.${k}.${module.config.environment}.radix.equinor.com/applications",
      "https://auth-radix-web-console-${local.environment}.${module.config.environment}.radix.equinor.com/applications",

      "https://console.radix.equinor.com/applications",
      "https://console.${k}.${module.config.environment}.radix.equinor.com/applications",
      "https://console.${module.config.environment}.radix.equinor.com/applications",
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
        data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["offline_access"],
        data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["openid"],
        data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["profile"],
      ]
    }
  }
}
