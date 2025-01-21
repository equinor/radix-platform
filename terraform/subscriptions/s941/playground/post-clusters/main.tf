locals {
  grafana_uris = [
    for k, v in module.clusters.oidc_issuer_url :
    "https://grafana.${k}.${module.config.environment}.radix.equinor.com/login/generic_oauth"
  ]

  environment = "qa"

  web-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:8000/oauth2/callback",

      "https://console.radix.equinor.com/oauth2/callback",
      "https://console.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://console.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",

      "https://web-radix-web-console-qa.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://web-radix-web-console-qa.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://web-radix-web-console-qa.radix.equinor.com/oauth2/callback",

      "https://web-radix-web-console-prod.${k}.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://web-radix-web-console-prod.${module.config.environment}.radix.equinor.com/oauth2/callback",
      "https://web-radix-web-console-prod.radix.equinor.com/oauth2/callback",
    ]]
  ))

  singlepage-uris = distinct(flatten(
    [for k, v in module.clusters.oidc_issuer_url : [
      "http://localhost:8080/applications",
      "https://web-radix-web-console-prod.${k}.${module.config.environment}.radix.equinor.com/applications",
      "https://web-radix-web-console-prod.${module.config.environment}.radix.equinor.com/applications",

      "https://web-radix-web-console-qa.${k}.${module.config.environment}.radix.equinor.com/applications",
      "https://web-radix-web-console-qa.${module.config.environment}.radix.equinor.com/applications",

      "https://console.radix.equinor.com/applications",
      "https://console.${k}.${module.config.environment}.radix.equinor.com/applications",
      "https://console.${module.config.environment}.radix.equinor.com/applications",
    ]]
  ))
}



