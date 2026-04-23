### ServiceNow Proxy Federated Identity credentials
module "servicenow" {
  source          = "../../../modules/federated-credentials/servicenow_proxy"
  oidc_issuer_url = local.oidc_issuer_urls
  clientid        = module.config.ar-radix-servicenow-proxy-client
}
