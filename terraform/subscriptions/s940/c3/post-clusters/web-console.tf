locals {
  web-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:8000/oauth2/callback",
      "https://console.${module.config.dns_zone_name}/oauth2/callback",
      "https://web-radix-web-console-prod.${module.config.dns_zone_name}/oauth2/callback",
      "https://web-radix-web-console-prod.${k}.${module.config.dns_zone_name}/oauth2/callback",
      "https://web-radix-web-console-qa.${module.config.dns_zone_name}/oauth2/callback",
      "https://web-radix-web-console-qa.${k}.${module.config.dns_zone_name}/oauth2/callback",
    ]]
  ))

  singlepage-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:8080/applications",
      "https://console.${module.config.dns_zone_name}/applications",
      "https://web-radix-web-console-prod.${module.config.dns_zone_name}/applications",
      "https://web-radix-web-console-prod.${k}.${module.config.dns_zone_name}/applications",
      "https://web-radix-web-console-qa.${module.config.dns_zone_name}/applications",
      "https://web-radix-web-console-qa.${k}.${module.config.dns_zone_name}/applications",

    ]]
  ))
}

data "azuread_application" "webconsole" {
  display_name = "Radix Web Console - ${module.config.environment}"
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
