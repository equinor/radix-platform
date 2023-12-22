locals {
  aad_radix_group             = local.external_outputs.global.data.aad_radix_group
    gh_repo_branch_combinations = local.external_outputs.global.data.gh_repo_branch_combinations
  gh_repos                    = local.external_outputs.global.data.gh_repos
  location                    = local.external_outputs.common.data.location
  resource_group              = local.external_outputs.common.data.resource_group
}

data "azuread_group" "radix_group" {
  display_name = local.aad_radix_group
}

module "userassignedidentity" {
  for_each            = local.gh_repo_branch_combinations
  source              = "../../../modules/userassignedidentity"
  name                = "id-radix-github-workflows-${each.value.name}"
  resource_group_name = local.resource_group
  location            = local.location
}
