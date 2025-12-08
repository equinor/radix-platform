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

data "azuread_group" "radix-platform-developers" {
  display_name     = "Radix Platform Developers"
  security_enabled = true
}

data "azuread_group" "azappl_developers" {
  display_name     = "AZAPPL ${module.config.environment} - Contributor"
  security_enabled = true
}

data "azurerm_role_definition" "azappl_confidential_data_contributor" {
  name  = "Radix Confidential Data Contributor"
  scope = "/subscriptions/${module.config.subscription}"
}
# NOTE: The previous 'terraform-contributor' role assignment resource was removed.
# It was replaced by the 'azappl_confidential_data_contributor' role assignment below.
# This change was made because the previous role assignment is no longer needed for current access patterns.
# All necessary permissions have been migrated to the new role assignment.
# If you need the old role assignment, please review access requirements and update accordingly.
resource "azurerm_pim_eligible_role_assignment" "azappl_developers" {
  principal_id       = data.azuread_group.azappl_developers.object_id
  role_definition_id = data.azurerm_role_definition.azappl_confidential_data_contributor.id
  scope              = "/subscriptions/${module.config.subscription}"
  schedule {
    expiration {
      duration_days = 365
    }
  }
}
