provider "azurerm" {
  features {}
}

locals {
  backup_location = "azure_backup_vault_${var.storage_accounts.location.name}"
  
}
# rule_mapping = {
#   backup_location = "azure_backup_vault_${var.storage_accounts.location}"
# }

variable "storage_accounts" {
  type = map(object({
    name                              = string                          # Mandatory
    rg_name                           = string                          # Mandatory
    location                          = optional(string, "northeurope") # Optional
    kind                              = optional(string, "StorageV2")   # Optional
    repl                              = optional(string, "LRS")         # Optional
    tier                              = optional(string, "Standard")    # Optional
    backup_center                     = optional(bool, false)           # Optional      
    life_cycle                        = optional(bool, true)
    firewall                          = optional(bool, false)
    fw_rule                           = optional(string, "")
    container_delete_retention_policy = optional(bool, false)
    tags                              = optional(map(string), {})
    allow_nested_items_to_be_public   = optional(bool, true)
    shared_access_key_enabled         = optional(bool, true)
    delete_retention_policy           = optional(bool, false)           # Must be true if kind = "BlobStorage" and want "Enable soft delete for blobs"
    versioning_enabled                = optional(bool, false)            #
    change_feed_enabled               = optional(bool, false)
    blobstorage_backup                = optional(bool, false)
  }))
  default = {}
}


resource "azurerm_storage_account" "storageaccounts" {
  for_each                         = var.storage_accounts
  name                             = each.value["name"]
  resource_group_name              = each.value["rg_name"]
  location                         = each.value["location"]
  account_kind                     = each.value["kind"]
  account_replication_type         = each.value["repl"]
  account_tier                     = each.value["tier"]
  allow_nested_items_to_be_public  = each.value["allow_nested_items_to_be_public"]
  cross_tenant_replication_enabled = false
  shared_access_key_enabled        = each.value["shared_access_key_enabled"]
  tags                             = each.value["tags"]

  blob_properties {
    versioning_enabled  = each.value["versioning_enabled"]
    change_feed_enabled = each.value["change_feed_enabled"]
    

    dynamic "delete_retention_policy" {
      for_each = each.value["delete_retention_policy"] == true ? [30] : []

      content {
        days = delete_retention_policy.value
      }
    }

    dynamic "container_delete_retention_policy" {
      for_each = each.value["versioning_enabled"] == true ? [30] : []

      content {
        days = container_delete_retention_policy.value
      }

    }
    dynamic "delete_retention_policy" {
      for_each = each.value["backup_center"] == true ? [35] : []

      content {
        days = delete_retention_policy.value
      }
    }

  }
}

output "myvalue" {
  value = local.backup_location
}

# ##########################################################################################
# # Role assignment
# resource "azurerm_role_assignment" "az_roleassignemnt" {
#   for_each             = { for mykey in compact([for mykey, myvalue in var.storage_accounts : myvalue.backup_center ? mykey : ""]) : mykey => var.storage_accounts[mykey] }
#   scope                = azurerm_storage_account.storageaccounts[each.key].id
#   role_definition_name = "Storage Account Backup Contributor"
#   #principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault_northeurope.identity[0].principal_id
#   principal_id         = azurerm_data_protection_backup_vault.local.backup_location.storage_accounts.location.identity[0].principal_id
#   depends_on           = [azurerm_storage_account.storageaccounts]
# }
# ##########################################################################################
# # Role assignment

# resource "azurerm_role_assignment" "az_roleassignemnt" {
#   for_each             = { for mykey in compact([for mykey, myvalue in var.storage_accounts : myvalue.backup_center ? mykey : ""]) : mykey => var.storage_accounts[mykey] }
#   scope                = azurerm_storage_account.storageaccounts[each.key].id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
#   depends_on           = [azurerm_storage_account.storageaccounts]
# }

# ##########################################################################################
# # Data Protection

# resource "azurerm_data_protection_backup_instance_blob_storage" "az_backup_instance" {
#   for_each           = { for mykey in compact([for mykey, myvalue in var.storage_accounts : myvalue.backup_center ? mykey : ""]) : mykey => var.storage_accounts[mykey] }
#   name               = each.value.name
#   vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
#   location           = each.value.location
#   storage_account_id = azurerm_storage_account.storageaccounts[each.key].id
#   backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
#   depends_on         = [azurerm_role_assignment.az_roleassignemnt]
# }


# ##########################################################################################
# # Management Policy

resource "azurerm_storage_management_policy" "sapolicy" {
  for_each           = { for mykey in compact([for mykey, myvalue in var.storage_accounts : myvalue.life_cycle ? mykey : ""]) : mykey => var.storage_accounts[mykey] }
  storage_account_id = azurerm_storage_account.storageaccounts[each.key].id

  rule {
    name    = "Lifecycle"
    enabled = true
    filters {
      blob_types = ["blockBlob"]
    }
    actions {
      version {
        delete_after_days_since_creation = 90
      }
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than        = 30
        tier_to_archive_after_days_since_last_tier_change_greater_than = 7
        tier_to_archive_after_days_since_modification_greater_than     = 90
        delete_after_days_since_modification_greater_than              = 730
      }
    }
  }
}

##########################################################################################
# Protection Vault

resource "azurerm_data_protection_backup_vault" "azure_backup_vault_northeurope" {
  name                = "s940-azure-backupvault-northeurope"
  resource_group_name = "backups"
  location            = "northeurope"
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_data_protection_backup_vault" "azure_backup_vault_westeurope" {
  name                = "s940-azure-backupvault-westeurope"
  resource_group_name = "backups"
  location            = "westeurope"
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"
  identity {
    type = "SystemAssigned"
  }
}

##########################################################################################
# Protection Backup Policy

resource "azurerm_data_protection_backup_policy_blob_storage" "backup_policy_s940_northeurope" {
  name               = "s940-azure-blob-backuppolicy-northeurope"
  vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault_northeurope.id
  retention_duration = "P30D"
  depends_on         = [azurerm_data_protection_backup_vault.azure_backup_vault_northeurope]
}

resource "azurerm_data_protection_backup_policy_blob_storage" "backup_policy_s940_westeurope" {
  name               = "s940-azure-blob-backuppolicy-westeurope"
  vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault_westeurope.id
  retention_duration = "P30D"
  depends_on         = [azurerm_data_protection_backup_vault.azure_backup_vault_westeurope]
}
