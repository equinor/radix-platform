locals {
  userassignedidentities      = local.external_outputs.userassignedidentity.data
  gh_repo_branch_combinations = local.external_outputs.global.data.gh_repo_branch_combinations
}

module "federatedcredential" {
  for_each            = local.userassignedidentities
  source              = "../../../modules/federatedcredential"
  parent_id           = each.value.data.id
  audiences           = ["api://AzureADTokenExchange"]
  name                = each.key
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:equinor/${local.gh_repo_branch_combinations[each.key].repo}:ref:refs/heads/${local.gh_repo_branch_combinations[each.key].branch}"
  resource_group_name = local.external_outputs.common.data.resource_group
}
