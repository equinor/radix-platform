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
  name                = module.config.backend.storage_account_name
  resource_group_name = module.config.backend.resource_group_name
}

resource "azurerm_role_assignment" "terraform-contributor" {
  principal_id       = data.terraform_remote_state.global_groups.outputs.radix_platform_developers.object_id
  scope              = data.azurerm_storage_account.infra.id
  role_definition_id = azurerm_role_definition.terraform-state-contributor.role_definition_resource_id
}
