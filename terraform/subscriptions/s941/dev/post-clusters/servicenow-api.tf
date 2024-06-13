### ServiceNow Proxy Federated Identity credentials
module "dev-radix-servicenow-proxy-federated-identity-credentials" {
  source = "../../../modules/federated-credentials/servicenow_proxy"
  oidc_issuer_url = module.clusters.oidc_issuer_url
}
