locals {
  environment = "prod"
  web-uris = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://auth-radix-web-console-${local.environment}.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback"
  ]
  singlepage-uris = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://auth-radix-web-console-${local.environment}.${k}.${module.config.environment}.radix.equinor.com/applications"
  ]

  singlepage_uris = [
    "https://console.playground.radix.equinor.com/applications",
    "https://auth-radix-web-console-qa.playground.radix.equinor.com/applications",
  ]

  web_uris = [
    "https://auth-radix-web-console-qa.${module.config.environment}.radix.equinor.com/oauth2/callback",
    "https://auth-radix-web-console-${local.environment}.${module.config.environment}.radix.equinor.com/oauth2/callback",
    "https://console.${module.config.environment}.radix.equinor.com/oauth2/callback",
  ]
}

module "webconsole" {
  source          = "../../../modules/app_registration"
  display_name    = "Omnia Radix Web Console - Playground Clusters" #TODO
  notes           = "Omnia Radix Web Console - Playground Clusters"
  service_id      = "110327"
  web_uris        = concat(local.web_uris, local.web-uris)
  singlepage_uris = concat(local.singlepage_uris, local.singlepage-uris) # local.singlepage_uris
  owners          = data.azuread_group.radix.members
}