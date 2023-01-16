terraform {
  backend "azurerm" {}
}
provider "azurerm" {
  features {}
}

locals {

  # stgaccts = jsondecode(file("salist.json"))
  # rule_mapping = {
  #     change_feed_enabled = var.address_space
  #     private = "${data.http.my_ip.body}/32"
  #     subnet = var.subnet_prefixes[0]
  #     all = "*"
  # }
}

##########################################################################################
# Variables
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
    firewall                          = optional(bool, true)
    ip_rule                           = optional(list(string), ["143.97.110.1"])
    container_delete_retention_policy = optional(bool, true)
    tags                              = optional(map(string), {})
    allow_nested_items_to_be_public   = optional(bool, false) #GUI: Configuration | Allow Blob public access
    shared_access_key_enabled         = optional(bool, true)
    cross_tenant_replication_enabled  = optional(bool, true)
    delete_retention_policy           = optional(bool, true)
    versioning_enabled                = optional(bool, true)
    change_feed_enabled               = optional(bool, true)
  }))
  default = {}
}
variable "vnets" {
  type = map(object({
    vnet_name   = string
    rg_name     = optional(string, "clusters")
    subnet_name = string
  }))
  default = {
    "vnet-anneli-test" = {
      vnet_name   = "vnet-anneli-test"
      subnet_name = "subnet-anneli-test"
    }
    "vnet-magnus-test" = {
      vnet_name   = "vnet-magnus-test"
      subnet_name = "subnet-magnus-test"
    }
    "vnet-playground-07" = {
      vnet_name   = "vnet-playground-07"
      subnet_name = "subnet-playground-07"
    }
    "vnet-weekly-02" = {
      vnet_name   = "vnet-weekly-02"
      subnet_name = "subnet-weekly-02"
    }
    "vnet-weekly-52" = {
      vnet_name   = "vnet-weekly-52"
      subnet_name = "subnet-weekly-52"
    }
  }
}

##########################################################################################
# Virtual Network
data "azurerm_virtual_network" "vnets" {
  for_each            = var.vnets
  name                = each.value["vnet_name"]
  resource_group_name = each.value["rg_name"]
}

data "azurerm_subnet" "subnets" {
  for_each             = var.vnets
  name                 = each.value["subnet_name"]
  resource_group_name  = each.value["rg_name"]
  virtual_network_name = each.value["vnet_name"]
}

##########################################################################################
# Storage Accounts
resource "azurerm_storage_account" "storageaccounts" {
  for_each                         = var.storage_accounts
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
    for_each = each.value["kind"] == "BlobStorage" ? [1] : [0]

    content {
      change_feed_enabled = each.value["change_feed_enabled"]
      versioning_enabled  = each.value["versioning_enabled"]

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

##########################################################################################
# Network rules

resource "azurerm_storage_account_network_rules" "network_rule" {
  for_each                   = { for key in compact([for key, value in var.storage_accounts : value.firewall ? key : ""]) : key => var.storage_accounts[key] }
  storage_account_id         = azurerm_storage_account.storageaccounts[each.key].id
  default_action             = "Deny"
  ip_rules                   = each.value["ip_rule"]
  virtual_network_subnet_ids = values(data.azurerm_subnet.subnets)[*].id
  bypass                     = ["AzureServices"]
}

##########################################################################################
# Role assignment
resource "azurerm_role_assignment" "northeurope" {
  for_each             = { for key in compact([for key, value in var.storage_accounts : value.backup_center && value.location == "northeurope" && value.kind == "StorageV2" ? key : ""]) : key => var.storage_accounts[key] }
  scope                = azurerm_storage_account.storageaccounts[each.key].id
  role_definition_name = "Storage Account Backup Contributor"
  principal_id         = azurerm_data_protection_backup_vault.northeurope.identity[0].principal_id
  depends_on           = [azurerm_storage_account.storageaccounts]
}

##########################################################################################
# Blob Protection

resource "azurerm_data_protection_backup_instance_blob_storage" "northeurope" {
  for_each           = { for key in compact([for key, value in var.storage_accounts : value.backup_center && value.location == "northeurope" && value.kind == "StorageV2" ? key : ""]) : key => var.storage_accounts[key] }
  name               = each.value.name
  vault_id           = azurerm_data_protection_backup_vault.northeurope.id
  location           = each.value.location
  storage_account_id = azurerm_storage_account.storageaccounts[each.key].id
  backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.northeurope.id
  depends_on         = [azurerm_role_assignment.northeurope]
}

###########################################################################################
# Management Policy

resource "azurerm_storage_management_policy" "sapolicy" {
  for_each           = { for key in compact([for key, value in var.storage_accounts : value.life_cycle ? key : ""]) : key => var.storage_accounts[key] }
  storage_account_id = azurerm_storage_account.storageaccounts[each.key].id

  rule {
    name    = "Lifecycle-dev"
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

##########################################################################################
# Protection Vault

resource "azurerm_data_protection_backup_vault" "northeurope" {
  name                = "s941-azure-backup-vault-northeurope"
  resource_group_name = "backups"
  location            = "northeurope"
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"
  identity {
    type = "SystemAssigned"
  }
}

##########################################################################################
# Protection Backup Policy

resource "azurerm_data_protection_backup_policy_blob_storage" "northeurope" {
  name               = "s941-azure-blob-backuppolicy-northeurope"
  vault_id           = azurerm_data_protection_backup_vault.northeurope.id
  retention_duration = "P30D"
}
