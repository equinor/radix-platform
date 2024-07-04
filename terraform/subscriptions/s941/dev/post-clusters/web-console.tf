locals {
  environment = "qa"
  web-uris = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://auth-radix-web-console-${local.environment}.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback"
  ]
  singlepage-uris = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://auth-radix-web-console-${local.environment}.${k}.${module.config.environment}.radix.equinor.com/applications"
  ]

  singlepage_uris = [
    "http://localhost:3000/applications",
    "http://localhost:8000/applications",
    "https://auth-radix-web-console-prod.${module.config.environment}.radix.equinor.com/applications",
    "https://auth-radix-web-console-prod.radix.equinor.com/swaggerui",
    "https://auth-radix-web-console-${local.environment}.${module.config.environment}.radix.equinor.com/swaggerui",
  "https://console.${module.config.environment}.radix.equinor.com/applications"]

  web_uris = [
    "https://app-oauthtest-spike.${module.config.environment}.radix.equinor.com/oauth2/callback",
    "https://auth-radix-web-console-prod.${module.config.environment}.radix.equinor.com/oauth2/callback",
    "https://auth-radix-web-console-${local.environment}.${module.config.environment}.radix.equinor.com/oauth2/callback",
    "https://console.${module.config.environment}.radix.equinor.com/auth-callback",
    "https://console.${module.config.environment}.radix.equinor.com/oauth2/callback",
    "https://console.radix.equinor.com/auth-callback",
    "https://console.radix.equinor.com/oauth2/callback",
    "http://localhost:3000/oauth2/callback",
    "http://localhost:8000/oauth2/callback",
    "http://localhost:8001/oauth2/callback",
    "http://localhost:8008/oauth2/callback",
    "https://server-radix-api-${module.config.environment}.${module.config.environment}.radix.equinor.com/oauth2/callback",
    "https://host.docker.internal:8000/oauth2/callback",
    "https://web-radix-web-console-${local.environment}.${module.config.environment}.radix.equinor.com/auth-callback"
  ]
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
  display_name    = "Omnia Radix Web Console - Development" #TODO
  notes           = "Omnia Radix Web Console - Development"
  service_id      = "110327"
  web_uris        = concat(local.web_uris, local.web-uris)
  singlepage_uris = concat(local.singlepage_uris, local.singlepage-uris) # local.singlepage_uris
  owners          = data.azuread_group.radix.members

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
