locals {
  web-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:8000/oauth2/callback",

      "https://console.radix.equinor.com/oauth2/callback",
      "https://console.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://console.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",

      "https://web-radix-web-console-prod.${k}.radix.equinor.com/oauth2/callback",
      "https://web-radix-web-console-prod.radix.equinor.com/oauth2/callback",

      "https://web-radix-web-console-qa.${k}.radix.equinor.com/oauth2/callback",
      "https://web-radix-web-console-qa.radix.equinor.com/oauth2/callback",
    ]]
  ))

  singlepage-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:8080/applications",

      "https://web-radix-web-console-prod.${k}.radix.equinor.com/applications",
      "https://web-radix-web-console-prod.radix.equinor.com/applications",

      "https://web-radix-web-console-qa.${k}.radix.equinor.com/applications",
      "https://web-radix-web-console-qa.radix.equinor.com/applications",

      "https://console.radix.equinor.com/applications",
      "https://console.${k}.radix.equinor.com/applications",
    ]]
  ))
}

data "azuread_application" "webconsole" {
  display_name = "Omnia Radix Web Console - Platform"
}

module "webconsole_redirect_uris" {
  source         = "../../../modules/app_registration_redirect_uris"
  application_id = data.azuread_application.webconsole.id
  type           = "Web"
  redirect_uris  = local.web-uris
}

module "webconsole_spa" {
  source         = "../../../modules/app_registration_redirect_uris"
  application_id = data.azuread_application.webconsole.id
  type           = "SPA"
  redirect_uris  = local.singlepage-uris
}

module "webconsole_fedcred_qa" {
  for_each       = module.clusters.oidc_issuer_url
  source         = "../../../modules/app_application_federated_credentials"
  application_id = data.azuread_application.webconsole.id
  display_name   = "${each.key}-qa"
  issuer         = each.value
  subject        = "system:serviceaccount:radix-web-console-qa:web-aux-oauth-sa"
}

module "webconsole_fedcred_prod" {
  for_each       = module.clusters.oidc_issuer_url
  source         = "../../../modules/app_application_federated_credentials"
  application_id = data.azuread_application.webconsole.id
  display_name   = "${each.key}-prod"
  issuer         = each.value
  subject        = "system:serviceaccount:radix-web-console-prod:web-aux-oauth-sa"
}
