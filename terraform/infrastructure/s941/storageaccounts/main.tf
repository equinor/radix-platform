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

variable "storage_accounts" {
  type = map(object({
    name          = string                          # Mandatory
    rg_name       = string                          # Mandatory
    location      = optional(string, "northeurope") # Optional
    kind          = optional(string, "StorageV2")   # Optional
    repl          = optional(string, "LRS")         # Optional
    tier          = optional(string, "Standard")    # Optional
    backup_center = optional(bool, false)           # Optional      
    life_cycle    = optional(bool, true)
    #firewall                          = optional(bool, false)
    #fw_rule                           = optional(string, "")
    container_delete_retention_policy = optional(bool, true)
    tags                              = optional(map(string), {})
    allow_nested_items_to_be_public   = optional(bool, false) #GUI: Configuration | Allow Blob public access
    shared_access_key_enabled         = optional(bool, true) #Config
    cross_tenant_replication_enabled  = optional(bool, true) #Config
    delete_retention_policy           = optional(bool, true) # Must be true if kind = "BlobStorage" and want "Enable soft delete for blobs"
    versioning_enabled                = optional(bool, true) #
    change_feed_enabled               = optional(bool, true)
  }))
  default = {}
}

# variable "vnet_name" {
#   description = "Name of the vnet to import."
#   type        = list(string)
#   default     = ["vnet-hub","vnet-hub"]
# }

# variable "vnet_rg" {
#   description = "Name of the resource grep related to the vnet_name."
#   type        = list(string)
#   default     = ["cluster-vnet-hub-dev","cluster-vnet-hub-playground"]
# }

# variable "additional_tags" {
#   default     = { "ServiceNow-App" : "OMNIA RADIX", "WBS" : "wbs-123" }
#   description = "Additional resource tags"
#   type        = map(string)
# }

variable "vnets" {
  type = map(object({
    vnet_name   = string
    rg_name     = string
    subnet_name = string
  }))
  default = {
    "hub_dev" = {
      vnet_name   = "vnet-hub"
      rg_name     = "cluster-vnet-hub-dev"
      subnet_name = "private-links"
    }
    "hub_playground" = {
      vnet_name   = "vnet-hub"
      rg_name     = "cluster-vnet-hub-playground"
      subnet_name = "private-links"
    }
  }
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

# data "azurerm_virtual_network" "vnets" {
#   for_each            = var.vnets
#   name                = each.value["vnet_name"]
#   resource_group_name = each.value["rg_name"]
# }

# data "azurerm_subnet" "subnets" {
#   for_each             = var.vnets
#   name                 = "private-links"
#   resource_group_name  = each.value["rg_name"]
#   virtual_network_name = each.value["vnet_name"]
# }

# resource "azurerm_storage_account_network_rules" "network_rule" {
#   for_each = { for mykey in compact([for mykey, myvalue in var.storage_accounts : myvalue.firewall ? mykey : ""]) : mykey => var.storage_accounts[mykey] }

#   storage_account_id         = azurerm_storage_account.storageaccounts[each.key].id
#   default_action             = "Deny"
#   ip_rules                   = []
#   virtual_network_subnet_ids = [data.azurerm_subnet.subnets[each.value["fw_rule"]].id]
#   bypass                     = ["AzureServices"]
#   depends_on                 = [data.azurerm_subnet.subnets]
# }

# output "virtual_network_subnet_ids" {
#   value = data.azurerm_subnet.subnets["hub_dev"].id
# }

# output "storageaccount" {
#   value = var.storage_accounts
# }


resource "azurerm_role_assignment" "northeurope" {
  #for_each             = { for key in compact([for key, value in var.storage_accounts : value.backup_center ? key : ""]) : key => var.storage_accounts[key] }
  for_each             = { for key in compact([for key, value in var.storage_accounts : value.backup_center ? key : false && value.location == "northeurope" ? key : false && value.kind == "StorageV2" ? key : ""]) : key => var.storage_accounts[key] }
  scope                = azurerm_storage_account.storageaccounts[each.key].id
  role_definition_name = "Storage Account Backup Contributor"
  principal_id         = azurerm_data_protection_backup_vault.northeurope.identity[0].principal_id
  depends_on           = [azurerm_storage_account.storageaccounts]
}

resource "azurerm_data_protection_backup_instance_blob_storage" "northeurope" {
  #for_each           = { for key in compact([for key, value in var.storage_accounts : value.backup_center ? key : ""]) : key => var.storage_accounts[key] }
  for_each           = { for key in compact([for key, value in var.storage_accounts : value.backup_center ? key : false && value.location == "northeurope" ? key : false && value.kind == "StorageV2" ? key : ""]) : key => var.storage_accounts[key] }
  name               = each.value.name
  vault_id           = azurerm_data_protection_backup_vault.northeurope.id
  location           = each.value.location
  storage_account_id = azurerm_storage_account.storageaccounts[each.key].id
  backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.northeurope.id
  depends_on         = [azurerm_role_assignment.northeurope]
}

# ##########################################################################################
# # Management Policy

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
        #tier_to_archive_after_days_since_last_tier_change_greater_than = 7
        delete_after_days_since_modification_greater_than = 90
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
##########################################################################################
# Virtual Network

# Dynamic




# data "azurerm_virtual_network" "vnet" {
#   for_each = toset(var.vnet_name)
#   name = each.value
#   resource_group_name = data.azurerm_virtual_network.vnet[each.key].id
#    #name                = data.azurerm_virtual_network.var.vnet[each.key].name
#   #resource_group_name = data.azurerm_resource_group.cluster_vnet_hub_dev.name
#   #resource_group_name = data.azurerm_resource_group[each.key]
#   #for_each = toset(var.vnet_name)
#   #name                = "vnet-hub"
#   #resource_group_name = data.azurerm_resource_group.cluster_vnet_hub_dev.name
#   #location            = data.azurerm_resource_group.cluster_vnet_hub_dev.location
#   #address_space       = [var.address_space]

#   # dynamic "subnet" {
#   #   for_each = zipmap(var.subnet_names,var.subnet_prefixes)
#   #     content {
#   #         name = subnet.key
#   #         address_prefix = subnet.value
#   #     }
#   # }
# }

################
# Dynamic



# data "azurerm_virtual_network" "vnets" {
#   for_each = zipmap(var.vnet_name,var.vnet_rg)

#   #name  = each.vnet.name
#   #resource_group_name = data.azurerm_resource_group.resourcegroups[each.key].name


# }

# data "azurerm_virtual_network" "vnets" {
#   for_each = zipmap(var.vnet_name,var.vnet_rg)
#     name = each.key
#     resource_group_name = data.azurerm_resource_group.resourcegroups[each.key].name

#   #name     = each.value
#   #resource_group_name = data.azurerm_resource_group.resourcegroups[each.key].name
# }

# data "azurerm_virtual_network" "vnets" {
#   for_each = zipmap(var.vnet_name,var.vnet_rg)
#   name = each.key
#   resource_group_name = data.azurerm_resource_group.cluster_vnet_hub_dev.name
# }

################
# Static

# data "azurerm_virtual_network" "vnet" {
#   name = "vnet-hub"
#   resource_group_name = data.azurerm_resource_group.cluster_vnet_hub_dev.name
# }



# data "azurerm_subnet" "subnet" {
#     name = "private-links"
#     resource_group_name = data.azurerm_resource_group.cluster_vnet_hub_dev.name
#     virtual_network_name = data.azurerm_virtual_network.vnet.name
# }


# resource "azurerm_storage_account_network_rules" "network_rules" {
#   storage_account_id = data.azurerm_storage_account.radixblobfusetestdev.id

#   default_action             = "Deny"
#   ip_rules                   = []
#   virtual_network_subnet_ids = [data.azurerm_subnet.subnet.id]
#   bypass                     = ["AzureServices"]
# }

#Not used
#  resource "azurerm_storage_account_network_rules" "network_rules" {
#   storage_account_id = data.azurerm_storage_account.radixblobfusetestdev.id

#   default_action             = "Allow"
#   ip_rules                   = ["127.0.0.1"]
#   virtual_network_subnet_ids = [data.azurerm_subnet.subnet.id]
#   bypass                     = ["Metrics"]
# }

