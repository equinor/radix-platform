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

data "azuread_group" "radix-platform-operators" {
  display_name     = "Radix Platform Operators"
  security_enabled = true
}

# resource "azurerm_role_assignment" "terraform-contributor" {
#   principal_id       = data.azuread_group.radix-platform-operators.object_id
#   scope              = data.azurerm_storage_account.infra.id
#   role_definition_id = azurerm_role_definition.terraform-state-contributor.role_definition_resource_id
# }

data "azuread_group" "azappl_developers" {
  display_name     = "AZAPPL ${module.config.environment} - Contributor"
  security_enabled = true
}

data "azurerm_role_definition" "azappl_confidential_data_contributor" {
  name  = "Radix Confidential Data Contributor"
  scope = "/subscriptions/${module.config.subscription}"
}
resource "azurerm_pim_eligible_role_assignment" "azappl_contributor" {
  principal_id       = data.azuread_group.azappl_developers.object_id
  role_definition_id = data.azurerm_role_definition.azappl_confidential_data_contributor.id
  scope              = "/subscriptions/${module.config.subscription}"
  schedule {
    expiration {
      duration_days = 365
    }
  }
}

