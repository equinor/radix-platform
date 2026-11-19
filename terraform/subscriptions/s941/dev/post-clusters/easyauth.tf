locals {
  easyauth_dex_subject = "system:serviceaccount:radix-easyauth:radix-easyauth-dex"
}

data "azuread_application" "easyauth" {
  display_name = "Radix EasyAuth Dev"
}

data "azurerm_user_assigned_identity" "easyauth-dex" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-easyauth-dex-${module.config.environment}"
}

module "easyauth_redirect_uris" {
  source         = "../../../modules/app_registration_redirect_uris"
  application_id = data.azuread_application.easyauth.id
  type           = "Web"
  redirect_uris  = [for cluster, _ in module.clusters.oidc_issuer_url : "https://easyauth.${cluster}.${module.config.dns_zone_name}/callback"]
}

# Dex signs in to Entra with clientAssertion
module "easyauth_fedcred" {
  for_each       = module.clusters.oidc_issuer_url
  source         = "../../../modules/app_application_federated_credentials"
  application_id = data.azuread_application.easyauth.id
  display_name   = "k8s-radix-easyauth-dex-${each.key}"
  issuer         = each.value
  subject        = local.easyauth_dex_subject
}

# The pgpass sidecar gets Postgres tokens as the Dex managed identity
module "easyauth-dex-mi-fedcred" {
  for_each            = module.clusters.oidc_issuer_url
  source              = "../../../modules/federated-credentials"
  name                = "k8s-radix-easyauth-dex-${each.key}"
  issuer              = each.value
  subject             = local.easyauth_dex_subject
  parent_id           = data.azurerm_user_assigned_identity.easyauth-dex.id
  resource_group_name = data.azurerm_user_assigned_identity.easyauth-dex.resource_group_name
}
