### ServiceNow Proxy Federated Identity credentials
module "c2-radix-servicenow-proxy-federated-identity-credentials" {
  source = "../../../modules/federated-credentials/servicenow_proxy"
  oidc_issuer_url = module.clusters.oidc_issuer_url
}
