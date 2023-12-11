module "federatedcredential" {
  source     = "../../../modules/federatedcredential"
  parent_id  = local.external_outputs.userassignedidentity.outputs.userassignedidentity.id
  audiences = ["api://AzureADTokenExchange"]
  name = "radix-canary-master"
  issuer = "https://token.actions.githubusercontent.com"
  subject = "repo:equinor/radix-canary:ref:refs/heads/master"
  resource_group_name = "common"
}
