data "azuread_application" "webconsole" {
  display_name = "Radix Web Console - Platform"
}

module "webconsole_redirect_uris" {
  source         = "../../../modules/webconsole_redirect_uris"
  application_id = data.azuread_application.webconsole.id
  dns_zone_name  = module.config.dns_zone_name
  cluster_names  = local.oidc_issuer_urls
}
