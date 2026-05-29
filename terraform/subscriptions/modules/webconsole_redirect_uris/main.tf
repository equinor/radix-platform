locals {
  web_uris = distinct(flatten(
    [for k, v in var.cluster_names : [
      "http://localhost:8000/oauth2/callback",
      "https://console.${var.dns_zone_name}/oauth2/callback",
      "https://web-radix-web-console-qa.${k}.${var.dns_zone_name}/oauth2/callback",
      "https://web-radix-web-console-qa.${var.dns_zone_name}/oauth2/callback",
      "https://web-radix-web-console-prod.${k}.${var.dns_zone_name}/oauth2/callback",
      "https://web-radix-web-console-prod.${var.dns_zone_name}/oauth2/callback",
    ]]
  ))

  spa_uris = distinct(flatten(
    [for k, v in var.cluster_names : [
      "http://localhost:8080/applications",
      "https://console.${var.dns_zone_name}/applications",
      "https://web-radix-web-console-prod.${k}.${var.dns_zone_name}/applications",
      "https://web-radix-web-console-prod.${var.dns_zone_name}/applications",
      "https://web-radix-web-console-qa.${k}.${var.dns_zone_name}/applications",
      "https://web-radix-web-console-qa.${var.dns_zone_name}/applications",
    ]]
  ))
}

module "web_redirect_uris" {
  source         = "../app_registration_redirect_uris"
  application_id = var.application_id
  type           = "Web"
  redirect_uris  = local.web_uris
}

module "spa_redirect_uris" {
  source         = "../app_registration_redirect_uris"
  application_id = var.application_id
  type           = "SPA"
  redirect_uris  = local.spa_uris
}
