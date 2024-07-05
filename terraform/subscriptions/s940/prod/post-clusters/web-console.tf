locals {
  environment = "prod"
  web-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:3000/auth-callback",

      "https://console.radix.equinor.com/oauth2/callback",
      "https://console.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://console.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",

      "https://auth-radix-web-console-${local.environment}.${k}.radix.equinor.com/oauth2/callback",
      "https://auth-radix-web-console-${local.environment}.radix.equinor.com/oauth2/callback",
    ]]
  ))

  singlepage-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:8080/applications",

      "https://auth-radix-web-console-${local.environment}.${k}.radix.equinor.com/applications",
      "https://auth-radix-web-console-${local.environment}.radix.equinor.com/applications",

      "https://console.radix.equinor.com/applications",
      "https://console.${k}.radix.equinor.com/applications",
    ]]
  ))

  singlepage-uris = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://auth-radix-web-console-prod.${k}.radix.equinor.com/applications"
  ]

  singlepage_uris = [
    "http://localhost:8080/applications",
    "https://auth-radix-web-console-prod.c2-11.c2.radix.equinor.com/applications",
    "https://auth-radix-web-console-qa.c2.radix.equinor.com/applications",
    "https://auth-radix-web-console-qa.radix.equinor.com/applications",
    "https://console.c2.radix.equinor.com/applications",
    "https://console.radix.equinor.com/applications",
    "https://auth-radix-web-console-prod.c2-prod-25.c2.radix.equinor.com/applications"
  ]

  web_uris = [
    "http://localhost:3000/auth-callback",
    "https://auth-radix-web-console-prod.c2-11.c2.radix.equinor.com/oauth2/callback",
    "https://auth-radix-web-console-prod.c2.radix.equinor.com/oauth2/callback",
    "https://auth-radix-web-console-qa.c2.radix.equinor.com/oauth2/callback",
    "https://auth-radix-web-console-qa.radix.equinor.com/oauth2/callback",
    "https://console.c2.radix.equinor.com/oauth2/callback",
    "https://console.dev.radix.equinor.com/auth-callback",
    "https://console.dev.radix.equinor.com/oauth2/callback",
    "https://console.playground.radix.equinor.com/auth-callback",
    "https://console.playground.radix.equinor.com/oauth2/callback",
    "https://console.radix.equinor.com/auth-callback",
    "https://console.radix.equinor.com/oauth2/callback",
    "https://web-radix-web-console-qa.radix.equinor.com/auth-callback"
  ]
}

module "webconsole" {
  source          = "../../../modules/app_registration"
  display_name    = "Omnia Radix Web Console - Production Clusters" #TODO
  service_id      = "110327"
  web_uris        = concat(local.web_uris, local.web-uris)
  singlepage_uris = concat(local.singlepage_uris, local.singlepage-uris)
  owners          = data.azuread_group.radix.members
  implicit_grant  = true
}
