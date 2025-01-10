### ServiceNow Proxy Federated Identity credentials
module "servicenow" {
  source          = "../../../modules/federated-credentials/servicenow_proxy"
  oidc_issuer_url = module.clusters.oidc_issuer_url
  clientid        = module.config.ar-radix-servicenow-proxy-client
}
