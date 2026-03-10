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

data "azuread_group" "contributors" {
  display_name     = module.config.subscription_contributor
  security_enabled = true
}

data "azurerm_role_definition" "azappl_confidential_data_contributor" {
  name  = "Radix Confidential Data Contributor"
  scope = "/subscriptions/${module.config.subscription}"
}

data "azurerm_role_definition" "radix_standard_reader" {
  name  = "Radix Standard Reader"
  scope = "/subscriptions/${module.config.subscription}"
}

resource "azurerm_role_assignment" "standard_reader" {
  principal_id       = data.azuread_group.contributors.object_id
  role_definition_id = data.azurerm_role_definition.radix_standard_reader.id
  scope              = "/subscriptions/${module.config.subscription}"
}

resource "azurerm_pim_eligible_role_assignment" "azappl_contributor" {
  principal_id       = data.azuread_group.contributors.object_id
  role_definition_id = data.azurerm_role_definition.azappl_confidential_data_contributor.id
  scope              = "/subscriptions/${module.config.subscription}"
  schedule {
    expiration {
      duration_days = 365
    }
  }
}

