locals {
  web-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:8000/oauth2/callback",
      "https://console.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://console.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://auth-radix-web-console-prod.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://auth-radix-web-console-prod.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://auth-radix-web-console-qa.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://auth-radix-web-console-qa.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",
    ]]
  ))

  singlepage-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:8080/applications",
      "https://console.${module.config.environment}.radix.equinor.com/applications",
      "https://console.${k}.${module.config.environment}.radix.equinor.com/applications",
      "https://auth-radix-web-console-prod.${module.config.environment}.radix.equinor.com/applications",
      "https://auth-radix-web-console-prod.${k}.${module.config.environment}.radix.equinor.com/applications",
      "https://auth-radix-web-console-qa.${module.config.environment}.radix.equinor.com/applications",
      "https://auth-radix-web-console-qa.${k}.${module.config.environment}.radix.equinor.com/applications",

    ]]
  ))
}

module "webconsole" {
  source              = "../../../modules/app_registration"
  display_name        = "Omnia Radix Web Console - C2" #TODO
  service_id          = "110327"
  web_uris            = local.web-uris
  singlepage_uris     = local.singlepage-uris
  owners              = data.azuread_group.radix.members
  implicit_grant      = false
  assignment_required = true
}
