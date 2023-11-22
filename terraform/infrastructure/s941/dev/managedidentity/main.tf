terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  subscription_id = var.AZ_SUBSCRIPTION_ID

  features {}
}

locals {
  storageaccount_role_assignment = merge([for storageaccount_key, storageaccount_value in data.azurerm_storage_account.storageaccounts : {
    for mi_key, mi_value in var.managed_identity :
    "${storageaccount_key}-${mi_key}" => {
      managedidentity = mi_value.name
      storageaccount  = storageaccount_value.name
      id              = storageaccount_value.id
    }
  }]...)

  loganalytics_role_assignment = merge([for loganalytics_key, loganalytics_value in data.azurerm_log_analytics_workspace.loganalytics : {
    for mi_key, mi_value in var.managed_identity :
    "${loganalytics_key}-${mi_key}" => {
      managedidentity = mi_value.name
      storageaccount  = loganalytics_value.name
      id              = loganalytics_value.id
    }
  }]...)
}

data "azurerm_log_analytics_workspace" "loganalytics" {
  for_each            = { for key in compact([for key, value in var.loganalytics : value.managed_identity ? key : ""]) : key => var.loganalytics[key] }
  name                = each.value["name"]
  resource_group_name = each.value["rg_name"]
}

data "azurerm_storage_account" "storageaccounts" {
  for_each            = { for key in compact([for key, value in var.storage_accounts : value.managed_identity ? key : ""]) : key => var.storage_accounts[key] }
  name                = each.value["name"]
  resource_group_name = each.value["rg_name"]
}

resource "azurerm_user_assigned_identity" "managed_identity" {
  for_each            = var.managed_identity
  name                = each.value["name"]
  location            = each.value["location"]
  resource_group_name = each.value["rg_name"]
}

resource "azurerm_role_assignment" "assign_identity_storage_blob_data_contributor" {
  for_each             = local.storageaccount_role_assignment
  scope                = each.value["id"]
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.managed_identity[each.value["managedidentity"]].principal_id
}

resource "azurerm_role_assignment" "assign_identity_log_analytics_reader" {
  for_each             = local.loganalytics_role_assignment
  scope                = each.value["id"]
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_user_assigned_identity.managed_identity[each.value["managedidentity"]].principal_id
}
