terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

locals {
  WHITELIST_IPS = jsondecode(textdecodebase64("${data.azurerm_key_vault_secret.whitelist_ips.value}", "UTF-8"))
}

data "azurerm_key_vault" "keyvault_env" {
  name                = "radix-vault-${var.RADIX_ZONE}"
  resource_group_name = var.AZ_RESOURCE_GROUP_COMMON
}

data "azurerm_key_vault_secret" "whitelist_ips" {
  name         = "kubernetes-api-server-whitelist-ips-${var.RADIX_ZONE}"
  key_vault_id = data.azurerm_key_vault.keyvault_env.id
}

#######################################################################################
### Storage Accounts
###

data "azurerm_storage_account" "storageaccounts" {
  for_each            = { for key in compact([for key, value in var.storage_accounts : value.create_with_rbac ? key : ""]) : key => var.storage_accounts[key] }
  name                = each.value["name"]
  resource_group_name = each.value["rg_name"]
}

resource "azurerm_storage_account" "storageaccounts" {
  for_each                         = { for key, value in var.storage_accounts : key => var.storage_accounts[key] if !value["create_with_rbac"] }
  name                             = each.value["name"]
  resource_group_name              = each.value["rg_name"]
  location                         = each.value["location"]
  account_kind                     = each.value["kind"]
  account_replication_type         = each.value["repl"]
  account_tier                     = each.value["tier"]
  allow_nested_items_to_be_public  = each.value["allow_nested_items_to_be_public"]
  cross_tenant_replication_enabled = each.value["cross_tenant_replication_enabled"]
  shared_access_key_enabled        = each.value["shared_access_key_enabled"]
  tags                             = each.value["tags"]

  dynamic "blob_properties" {
    for_each = each.value["kind"] == "BlobStorage" || each.value["kind"] == "Storage" ? [1] : [0]

    content {
      change_feed_enabled           = each.value["change_feed_enabled"]
      versioning_enabled            = each.value["versioning_enabled"]
      change_feed_retention_in_days = each.value["change_feed_days"]

      dynamic "container_delete_retention_policy" {
        for_each = each.value["container_delete_retention_policy"] == true ? [30] : []

        content {
          days = container_delete_retention_policy.value
        }
      }

      dynamic "delete_retention_policy" {
        for_each = each.value["delete_retention_policy"] == true ? [35] : []

        content {
          days = delete_retention_policy.value
        }
      }

      dynamic "restore_policy" {
        for_each = each.value["backup_center"] == true ? [30] : []

        content {
          days = restore_policy.value
        }
      }
    }
  }
}

#######################################################################################
### Network rules
###

resource "azurerm_storage_account_network_rules" "network_rule" {
  for_each           = { for key in compact([for key, value in var.storage_accounts : value.firewall ? key : ""]) : key => var.storage_accounts[key] }
  storage_account_id = var.storage_accounts[each.key].create_with_rbac ? data.azurerm_storage_account.storageaccounts[each.key].id : azurerm_storage_account.storageaccounts[each.key].id
  default_action     = "Deny"
  ip_rules           = compact([for key, value in local.WHITELIST_IPS.whitelist : endswith(value.ip, "/32") ? replace(value.ip, "/32", "") : ""])
  bypass             = ["AzureServices"]
}

#######################################################################################
### Role assignment
###

resource "azurerm_role_assignment" "northeurope" {
  for_each             = { for key in compact([for key, value in var.storage_accounts : value.backup_center && value.location == var.AZ_LOCATION && value.kind == "StorageV2" ? key : ""]) : key => var.storage_accounts[key] }
  scope                = var.storage_accounts[each.key].create_with_rbac ? data.azurerm_storage_account.storageaccounts[each.key].id : azurerm_storage_account.storageaccounts[each.key].id
  role_definition_name = "Storage Account Backup Contributor"
  principal_id         = azurerm_data_protection_backup_vault.northeurope.identity[0].principal_id
  depends_on           = [azurerm_storage_account.storageaccounts]
}

#######################################################################################
### Blob Protection
###

resource "azurerm_data_protection_backup_instance_blob_storage" "northeurope" {
  for_each           = { for key in compact([for key, value in var.storage_accounts : value.backup_center && value.location == var.AZ_LOCATION && value.kind == "StorageV2" ? key : ""]) : key => var.storage_accounts[key] }
  name               = each.value.name
  vault_id           = azurerm_data_protection_backup_vault.northeurope.id
  location           = each.value.location
  storage_account_id = var.storage_accounts[each.key].create_with_rbac ? data.azurerm_storage_account.storageaccounts[each.key].id : azurerm_storage_account.storageaccounts[each.key].id
  backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.northeurope.id
  depends_on         = [azurerm_role_assignment.northeurope]
}

#######################################################################################
### Management Policy
###

resource "azurerm_storage_management_policy" "sapolicy" {
  for_each           = { for key in compact([for key, value in var.storage_accounts : value.life_cycle ? key : ""]) : key => var.storage_accounts[key] }
  storage_account_id = var.storage_accounts[each.key].create_with_rbac ? data.azurerm_storage_account.storageaccounts[each.key].id : azurerm_storage_account.storageaccounts[each.key].id

  rule {
    name    = "lifecycle-${var.RADIX_ZONE}"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      version {
        delete_after_days_since_creation = 60
      }

      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
        delete_after_days_since_modification_greater_than       = 90
      }
    }
  }
}

#######################################################################################
### Protection Vault
###

resource "azurerm_data_protection_backup_vault" "northeurope" {
  name                = "s941-backupvault-${var.AZ_LOCATION}"
  resource_group_name = "backups"
  location            = var.AZ_LOCATION
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"

  identity {
    type = "SystemAssigned"
  }
}

#######################################################################################
### Protection Backup Policy
###

resource "azurerm_data_protection_backup_policy_blob_storage" "northeurope" {
  name               = "s941-backuppolicy-${var.AZ_LOCATION}"
  vault_id           = azurerm_data_protection_backup_vault.northeurope.id
  retention_duration = "P30D"
}
