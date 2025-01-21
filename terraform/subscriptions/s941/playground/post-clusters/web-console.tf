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