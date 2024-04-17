resource "azurerm_role_definition" "terraform-state-contributor" {

  name  = "Radix Terraform State Contributor ${module.config.environment}"
  scope = data.azurerm_subscription.main.id
  permissions {
    actions = [
      "Microsoft.Storage/storageAccounts/listKeys/action",
    ]
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete"
    ]
  }
}

data "azurerm_storage_account" "infra" {
  name                = "${module.config.environment}radixinfra"
  resource_group_name = "${module.config.environment}-tfstate"
}

data "azuread_group" "radix-platform-developers" {
  display_name     = "Radix Platform Developers"
  security_enabled = true
}

resource "azurerm_role_assignment" "terraform-contributor" {
  principal_id       = data.azuread_group.radix-platform-developers.object_id
  scope              = data.azurerm_storage_account.infra.id
  role_definition_id = azurerm_role_definition.terraform-state-contributor.role_definition_resource_id
}
