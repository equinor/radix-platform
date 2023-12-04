terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  subscription_id = var.AZ_SUBSCRIPTION_ID

  features {}
}

provider "azuread" {}

# locals {
#   github_repos_flattened = flatten([
#     for repo, branches in var.github_workflow_repos : [
#       for i, branch in branches : {
#         repo   = repo
#         branch = branch
#         index  = i
#       }
#     ]
#   ])
#   github_repos_grouped = chunklist(local.github_repos_flattened, 20)
#   github_repos_map     = { for repo in local.github_repos_flattened : "${repo.repo}-${repo.branch}" => repo }
# }

locals {
  github_repos_flattened = flatten([
    for repo, branches in var.github_workflow_repos : [
      for i, branch in branches : {
        repo      = repo
        branch    = branch
        index     = i
        # app_index = floor(i / 20.0)
      }
    ]
  ])
  github_repos_map = { for i, repo in local.github_repos_flattened : "${repo.repo}-${repo.branch}" => merge(repo, { app_index = floor(i / 20.0) }) }
}

data "azurerm_subscription" "AZ_SUBSCRIPTION" {
  subscription_id = var.AZ_SUBSCRIPTION_ID
}

data "azuread_group" "radix_group" {
  display_name = var.AAD_RADIX_GROUP
}

resource "azuread_application" "AR_GITHUB_WORKFLOW" {
  count            = ceil(length(local.github_repos_flattened) / 20)
  display_name     = "radix-github-workflows-${count.index + 1}-${var.RADIX_ZONE}-test"
  owners           = data.azuread_group.radix_group.members
  sign_in_audience = "AzureADandPersonalMicrosoftAccount"

  api {
    known_client_applications      = []
    mapped_claims_enabled          = false
    requested_access_token_version = 2
  }
}

resource "azuread_service_principal" "SP_GITHUB_ACTION_CLUSTER" {
  count                        = length(azuread_application.AR_GITHUB_WORKFLOW)
  application_id               = azuread_application.AR_GITHUB_WORKFLOW[count.index].application_id
  app_role_assignment_required = false
  owners                       = azuread_application.AR_GITHUB_WORKFLOW[count.index].owners
}

# resource "azuread_application_federated_identity_credential" "AR_GITHUB_WORKFLOW_FIC" {
#   for_each              = local.github_repos_map
#   application_object_id = azuread_application.AR_GITHUB_WORKFLOW[floor(each.value.index / 20.0)].object_id
#   display_name          = "${each.value.repo}-${each.value.branch}"
#   description           = "Allow authentication with push to ${each.value.branch} branch."
#   audiences             = ["api://AzureADTokenExchange"]
#   issuer                = "https://token.actions.githubusercontent.com"
#   subject               = "repo:equinor/${each.value.repo}:ref:refs/heads/${each.value.branch}"

#   timeouts {}
# }

# resource "azuread_application_federated_identity_credential" "AR_GITHUB_WORKFLOW_FIC" {
#   for_each              = local.github_repos_map
#   application_object_id = azuread_application.AR_GITHUB_WORKFLOW[each.value.app_index].object_id
#   display_name          = "${each.value.repo}-${each.value.branch}"
#   description           = "Allow authentication with push to ${each.value.branch} branch."
#   audiences             = ["api://AzureADTokenExchange"]
#   issuer                = "https://token.actions.githubusercontent.com"
#   subject               = "repo:equinor/${each.value.repo}:ref:refs/heads/${each.value.branch}"

#   timeouts {}
# }

resource "azuread_application_federated_identity_credential" "AR_GITHUB_WORKFLOW_FIC" {
  for_each              = local.github_repos_map
  application_object_id = azuread_application.AR_GITHUB_WORKFLOW[each.value.app_index].object_id
  display_name          = "${each.value.repo}-${each.value.branch}"
  description           = "Allow authentication with push to ${each.value.branch} branch."
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = "https://token.actions.githubusercontent.com"
  subject               = "repo:equinor/${each.value.repo}:ref:refs/heads/${each.value.branch}"

  timeouts {}
}