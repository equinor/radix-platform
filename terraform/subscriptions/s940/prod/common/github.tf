
data "azuread_application" "github_operator" {
  display_name = "OP-Terraform-Github Action"
}
data "azuread_service_principal" "github_operator" {
  display_name = data.azuread_application.github_operator.display_name
}
data "azurerm_storage_account" "infra" {
  name                = module.config.backend.storage_account_name
  resource_group_name = module.config.backend.resource_group_name
}
data "azurerm_subscription" "subscription" {
  subscription_id = module.config.subscription
}

resource "azurerm_role_assignment" "github-operator-contributor" {
  scope                = data.azurerm_subscription.subscription.id
  role_definition_name = "Contributor"
  principal_id         = data.azuread_service_principal.github_operator.object_id
}

resource "azurerm_role_assignment" "github-operator-data-owner" {
  scope                = data.azurerm_storage_account.infra.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azuread_service_principal.github_operator.object_id
}

resource "azurerm_role_assignment" "github-operator-user-admin" {
  scope                = data.azurerm_storage_account.infra.id
  role_definition_name = "User Access Administrator"
  principal_id         = data.azuread_service_principal.github_operator.object_id
}

resource "azuread_application_federated_identity_credential" "github-operator-federated-credentials" {
  application_id = data.azuread_application.github_operator.id
  display_name          = "radix-platform-operations"
  description           = "Allow Github to authenticate"
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = "https://token.actions.githubusercontent.com"
  subject               = "repo:equinor/radix-platform:environment:s940"

  timeouts {}
}
