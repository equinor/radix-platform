### ServiceNow Proxy client
data "azuread_application" "this" {
  display_name = "ar-radix-servicenow-proxy-client"
}

resource "azuread_application_federated_identity_credential" "ar-radix-servicenow-proxy-client" {
  for_each = module.clusters.oidc_issuer_url
  application_id = data.azuread_application.this.id
  display_name = "k8s-radix-servicenow-proxy-client-${each.key}"
  description  = "Application registration Federated Identity Credentials to access ServiceNow API"
  audiences    = ["api://AzureADTokenExchange"]
  issuer       = each.value
  subject      = "system:serviceaccount:radix-servicenow-proxy-qa:api-sa"
}

