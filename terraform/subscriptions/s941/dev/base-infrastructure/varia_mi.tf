module "radix-id-varia-doc_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-varia-doc"
  location            = module.config.location
  resource_group_name = module.resourcegroup_common.data.name
  federated_credentials = {
    radix_public_site_main = {
      name    = "radix-public-site-main"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-public-site:ref:refs/heads/main"
    }
  }
}