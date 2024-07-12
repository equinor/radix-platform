variable "oidc_issuer_url" {
  description = "OIDC issuer URLs for the clusters"
  type        = map(string)
}

data "azuread_application" "this" {
  display_name = "radix-ar-servicenow-proxy-client"
}

locals {
  oidc_issuers = flatten([
    for cluster, issuer in var.oidc_issuer_url : [
      for env in ["prod", "qa"] : {
        cluster = cluster
        issuer  = issuer
        env     = env
      }
    ]
  ])
}

resource "azuread_application_federated_identity_credential" "radix-ar-servicenow-proxy-client" {
  for_each       = { for item in local.oidc_issuers : "${item.cluster}-${item.env}" => item }
  application_id = data.azuread_application.this.id
  display_name   = "k8s-radix-servicenow-proxy-client-${each.value.cluster}-${each.value.env}"
  description    = "Application registration Federated Identity Credentials to access ServiceNow API"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = each.value.issuer
  subject        = "system:serviceaccount:radix-servicenow-proxy-${each.value.env}:api-sa"
}
