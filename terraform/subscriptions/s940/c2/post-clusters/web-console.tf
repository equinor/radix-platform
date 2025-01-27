locals {
  web-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:8000/oauth2/callback",
      "https://console.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://console.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://web-radix-web-console-prod.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://web-radix-web-console-prod.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://web-radix-web-console-qa.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://web-radix-web-console-qa.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",
    ]]
  ))

  singlepage-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:8080/applications",
      "https://console.${module.config.environment}.radix.equinor.com/applications",
      "https://console.${k}.${module.config.environment}.radix.equinor.com/applications",
      "https://web-radix-web-console-prod.${module.config.environment}.radix.equinor.com/applications",
      "https://web-radix-web-console-prod.${k}.${module.config.environment}.radix.equinor.com/applications",
      "https://web-radix-web-console-qa.${module.config.environment}.radix.equinor.com/applications",
      "https://web-radix-web-console-qa.${k}.${module.config.environment}.radix.equinor.com/applications",

    ]]
  ))
}

module "webconsole_redirect_uris" {
  source         = "../../../modules/app_registration_redirect_uris"
  application_id = "/applications/${module.config.appreg.web}"
  type           = "Web"
  redirect_uris  = local.web-uris
}

module "webconsole_spa" {
  source         = "../../../modules/app_registration_redirect_uris"
  application_id = "/applications/${module.config.appreg.web}"
  type           = "SPA"
  redirect_uris  = local.singlepage-uris
}
