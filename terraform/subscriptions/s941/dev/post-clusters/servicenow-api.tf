### ServiceNow Proxy client
data "azuread_application" "this" {
  display_name = "ar-radix-servicenow-proxy-client"
}

locals {
  environments = ["prod", "qa"]
  oidc_issuers = distinct(flatten([
    for env in local.environments : [
      for cluster, issuer in module.clusters.oidc_issuer_url : {
        cluster = cluster
        issuer = issuer
        env = env
      }
    ]
  ]))
}

resource "azuread_application_federated_identity_credential" "ar-radix-servicenow-proxy-client" {
  for_each = { for entry in local.oidc_issuers: "${entry.cluster}-${entry.env}" => entry }
  application_id = data.azuread_application.this.id
  display_name = "k8s-radix-servicenow-proxy-client-${each.key}"
  description  = "Application registration Federated Identity Credentials to access ServiceNow API"
  audiences    = ["api://AzureADTokenExchange"]
  issuer       = each.value.issuer
  subject      = "system:serviceaccount:radix-servicenow-proxy-${each.value.env}:api-sa"
}
