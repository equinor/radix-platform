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
    allow_nested_items_to_be_public   = optional(bool, false)
    shared_access_key_enabled         = optional(bool, true)
    delete_retention_policy           = optional(bool, false)           # Must be true if kind = "BlobStorage" and want "Enable soft delete for blobs"
    versioning_enabled                = optional(bool, true)            #
    change_feed_enabled               = optional(bool, true)
    blobstorage_backup                = optional(bool, false)
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


    # dynamic "restore_policy" {
    #   for_each = each.value["restore_policy"] == true ? [30] : []

    #   content {
    #     days = restore_policy.value
    #   }
    # }
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


resource "azurerm_role_assignment" "az_roleassignemnt" {
  for_each             = { for mykey in compact([for mykey, myvalue in var.storage_accounts : myvalue.backup_center ? mykey : ""]) : mykey => var.storage_accounts[mykey] }
  scope                = azurerm_storage_account.storageaccounts[each.key].id
  role_definition_name = "Storage Account Backup Contributor"
  principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
  depends_on           = [azurerm_storage_account.storageaccounts]
}

resource "azurerm_data_protection_backup_instance_blob_storage" "az_backup_instance" {
  for_each           = { for mykey in compact([for mykey, myvalue in var.storage_accounts : myvalue.backup_center ? mykey : ""]) : mykey => var.storage_accounts[mykey] }
  name               = each.value.name
  vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
  location           = each.value.location
  storage_account_id = azurerm_storage_account.storageaccounts[each.key].id
  backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
  depends_on         = [azurerm_role_assignment.az_roleassignemnt]
}

# ##########################################################################################
# # Management Policy

resource "azurerm_storage_management_policy" "sapolicy" {
  for_each           = { for mykey in compact([for mykey, myvalue in var.storage_accounts : myvalue.life_cycle ? mykey : ""]) : mykey => var.storage_accounts[mykey] }
  storage_account_id = azurerm_storage_account.storageaccounts[each.key].id

  rule {
    name    = "Lifecycle-dev"
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
        delete_after_days_since_modification_greater_than              = 2555
      }
    }
  }
}

##########################################################################################
# Protection Vault

resource "azurerm_data_protection_backup_vault" "azure_backup_vault" {
  name                = "azure-backup-vault-dev"
  resource_group_name = "common"
  location            = "northeurope"
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"
  identity {
    type = "SystemAssigned"
  }
}

##########################################################################################
# Protection Backup Policy

resource "azurerm_data_protection_backup_policy_blob_storage" "blob14days" {
  name               = "blob14days-dev"
  vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
  retention_duration = "P14D"
}

resource "azurerm_data_protection_backup_policy_blob_storage" "backup_policy_dev" {
  name               = "azure-blob-backuppolicy-dev"
  vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
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

##########################################################################################
# Resource groups

# data "azurerm_resource_group" "resourcegroups" {
#   for_each = toset(var.vnet_rg)
#   name     = each.value
# }


# data "azurerm_resource_group" "cluster_vnet_hub_dev" {
#   name     = "cluster-vnet-hub-dev"
# }

# data "azurerm_resource_group" "blob_fuse" {
#   name = "blob-fuse"
#   #  location = "northeurope"
# }

# data "azurerm_resource_group" "common" {
#   name = "common"
#   #  location = "northeurope"
# }

# data "azurerm_resource_group" "cost_allocation" {
#   name = "cost-allocation"
#   #  location = "northeurope"
# }

# data "azurerm_resource_group" "logs_dev" {
#   name = "Logs-Dev"
#   #  location = "northeurope"
# }

# data "azurerm_resource_group" "radix_aso_myapp_dev" {
#   name = "radix-aso-myapp-dev"
#   #  location = "northeurope"
# }

# data "azurerm_resource_group" "rg_radix_shared_dev" {
#   name = "rg-radix-shared-dev"
#   #  location = "norwayeast"
# }

# data "azurerm_resource_group" "s941_tfstate" {
#   name = "s941-tfstate"
#   #  location = "northeurope"
# }

# data "azurerm_resource_group" "velero_backups" {
#   name = "Velero_Backups"
#   #  location = "northeurope"
# }

##########################################################################################
# Storage account

# data "azurerm_storage_account" "blobbytest" {
#   name                = "blobbytest"
#   resource_group_name = data.azurerm_resource_group.blob_fuse.name
#   #  location                 = data.azurerm_resource_group.blob_fuse.location
#   #  account_tier             = "Standard"
#   #  account_replication_type = "LRS"
# }

# data "azurerm_storage_account" "costallocationdevsqllog" {
#   name                = "costallocationdevsqllog"
#   resource_group_name = data.azurerm_resource_group.cost_allocation.name
#   #  location                 = data.azurerm_resource_group.cost_allocation.location
#   #  account_tier             = "Standard"
#   #  account_replication_type = "LRS"
# }

# data "azurerm_storage_account" "myappdevstorageaccount" {
#   name                = "myappdevstorageaccount"
#   resource_group_name = data.azurerm_resource_group.radix_aso_myapp_dev.name
#   #  location                 = data.azurerm_resource_group.radix_aso_myapp_dev.location
#   #  account_tier             = "Standard"
#   #  account_replication_type = "LRS"
# }

# data "azurerm_storage_account" "radixazauditlogsdev" {
#   name                = "radixazauditlogsdev"
#   resource_group_name = data.azurerm_resource_group.rg_radix_shared_dev.name
#   #  location                 = data.azurerm_resource_group.rg_radix_shared_dev.location
#   #  account_tier             = "Standard"
#   #  account_replication_type = "LRS"
# }

# data "azurerm_storage_account" "radixblobfusetestdev" {
#   name                = "radixblobfusetestdev"
#   resource_group_name = data.azurerm_resource_group.blob_fuse.name
#   #  location                 = data.azurerm_resource_group.blob_fuse.location
#   #  account_tier             = "Standard"
#   #  account_replication_type = "LRS"
# }

# data "azurerm_storage_account" "radixblobfusevolumetest" {
#   name                = "radixblobfusevolumetest"
#   resource_group_name = data.azurerm_resource_group.blob_fuse.name
#   #  location                 = data.azurerm_resource_group.blob_fuse.location
#   #  account_tier             = "Standard"
#   #  account_replication_type = "RAGRS"
# }

# data "azurerm_storage_account" "radixflowlogsdev" {
#   name                = "radixflowlogsdev"
#   resource_group_name = data.azurerm_resource_group.logs_dev.name
#   #  location                 = data.azurerm_resource_group.logs_dev.location
#   #  account_tier             = "Standard"
#   #  account_replication_type = "LRS"
# }

# data "azurerm_storage_account" "radixinfradev" {
#   name                = "radixinfradev"
#   resource_group_name = data.azurerm_resource_group.s941_tfstate.name
#   #  location                 = data.azurerm_resource_group.s941_-tfstate.location
#   #  account_tier             = "Standard"
#   #  account_replication_type = "GRS"
# }

# data "azurerm_storage_account" "radixvelerodev" {
#   name                = "radixvelerodev"
#   resource_group_name = data.azurerm_resource_group.velero_backups.name
#   #  location                 = data.azurerm_resource_group.velero_backups.location
#   #  account_tier             = "Standard"
#   #  account_replication_type = "GRS"
# }

# data "azurerm_storage_account" "s941sqllogsdev" {
#   name                = "s941sqllogsdev"
#   resource_group_name = data.azurerm_resource_group.common.name
#   #  location                 = data.azurerm_resource_group.common.location
#   #  account_tier             = "Standard"
#   #  account_replication_type = "LRS"
# }

# data "azurerm_storage_account" "s941sqllogsplayground" {
#   name                = "s941sqllogsplayground"
#   resource_group_name = data.azurerm_resource_group.common.name
#   #  location                 = data.azurerm_resource_group.common.location
#   #  account_tier             = "Standard"
#   #  account_replication_type = "LRS"
# }



##########################################################################################
# Role Assignment

# resource "azurerm_role_assignment" "example" {
#   scope                = azurerm_storage_account.example.id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = data.azurerm_data_protection_backup_vault.example.identity[0].principal_id
# }

# resource "azurerm_role_assignment" "example" {
#   name               = "00000000-0000-0000-0000-000000000000"
#   scope              = data.azurerm_subscription.primary.id
#   role_definition_id = azurerm_role_definition.example.role_definition_resource_id
#   principal_id       = data.azurerm_client_config.example.object_id
# }




# resource "azurerm_role_assignment" "blobbytest" {
#   count = 11

# }

# resource "azurerm_role_assignment" "blobbytest" {
#   scope                = data.azurerm_storage_account.blobbytest.id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
# }

# resource "azurerm_role_assignment" "costallocationdevsqllog" {
#   scope                = data.azurerm_storage_account.costallocationdevsqllog.id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
# }

# resource "azurerm_role_assignment" "myappdevstorageaccount" {
#   scope                = data.azurerm_storage_account.myappdevstorageaccount.id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
# }

# resource "azurerm_role_assignment" "radixazauditlogsdev" {
#   scope                = data.azurerm_storage_account.radixazauditlogsdev.id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
# }

# resource "azurerm_role_assignment" "radixblobfusetestdev" {
#   scope                = data.azurerm_storage_account.radixblobfusetestdev.id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
# }

# resource "azurerm_role_assignment" "radixblobfusevolumetest" {
#   scope                = data.azurerm_storage_account.radixblobfusevolumetest.id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
# }

# resource "azurerm_role_assignment" "radixflowlogsdev" {
#   scope                = data.azurerm_storage_account.radixflowlogsdev.id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
# }

# resource "azurerm_role_assignment" "radixinfradev" {
#   scope                = data.azurerm_storage_account.radixinfradev.id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
# }

# resource "azurerm_role_assignment" "radixvelerodev" {
#   scope                = data.azurerm_storage_account.radixvelerodev.id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
# }

# resource "azurerm_role_assignment" "s941sqllogsdev" {
#   scope                = data.azurerm_storage_account.s941sqllogsdev.id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
# }

# resource "azurerm_role_assignment" "s941sqllogsplayground" {
#   scope                = data.azurerm_storage_account.s941sqllogsplayground.id
#   role_definition_name = "Storage Account Backup Contributor"
#   principal_id         = azurerm_data_protection_backup_vault.azure_backup_vault.identity[0].principal_id
# }




##########################################################################################
# Backup Instances

# resource "azurerm_data_protection_backup_instance_blob_storage" "blobbytest" {
#   name               = "blobbytest"
#   vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
#   location           = data.azurerm_resource_group.blob_fuse.location
#   storage_account_id = data.azurerm_storage_account.blobbytest.id
#   backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
#   depends_on         = [azurerm_role_assignment.blobbytest]
# }

# resource "azurerm_data_protection_backup_instance_blob_storage" "costallocationdevsqllog" {
#   name               = "costallocationdevsqllog"
#   vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
#   location           = data.azurerm_resource_group.cost_allocation.location
#   storage_account_id = data.azurerm_storage_account.costallocationdevsqllog.id
#   backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
#   depends_on         = [azurerm_role_assignment.costallocationdevsqllog]
# }

# resource "azurerm_data_protection_backup_instance_blob_storage" "myappdevstorageaccount" {
#   name               = "myappdevstorageaccount"
#   vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
#   location           = data.azurerm_resource_group.radix_aso_myapp_dev.location
#   storage_account_id = data.azurerm_storage_account.myappdevstorageaccount.id
#   backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
#   depends_on         = [azurerm_role_assignment.myappdevstorageaccount]
# }

# resource "azurerm_data_protection_backup_instance_blob_storage" "radixazauditlogsdev" {
#   name               = "radixazauditlogsdev"
#   vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
#   location           = data.azurerm_resource_group.rg_radix_shared_dev.location
#   storage_account_id = data.azurerm_storage_account.radixazauditlogsdev.id
#   backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
#   depends_on         = [azurerm_role_assignment.radixazauditlogsdev]
# }

# resource "azurerm_data_protection_backup_instance_blob_storage" "radixblobfusetestdev" {
#   name               = "radixblobfusetestdev"
#   vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
#   location           = data.azurerm_resource_group.blob_fuse.location
#   storage_account_id = data.azurerm_storage_account.radixblobfusetestdev.id
#   backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
#   depends_on         = [azurerm_role_assignment.radixblobfusetestdev]
# }

# resource "azurerm_data_protection_backup_instance_blob_storage" "radixblobfusevolumetest" {
#   name               = "radixblobfusevolumetest"
#   vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
#   location           = data.azurerm_resource_group.blob_fuse.location
#   storage_account_id = data.azurerm_storage_account.radixblobfusevolumetest.id
#   backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
#   depends_on         = [azurerm_role_assignment.radixblobfusevolumetest]
# }

# resource "azurerm_data_protection_backup_instance_blob_storage" "radixflowlogsdev" {
#   name               = "radixflowlogsdev"
#   vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
#   location           = data.azurerm_resource_group.logs_dev.location
#   storage_account_id = data.azurerm_storage_account.radixflowlogsdev.id
#   backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
#   depends_on         = [azurerm_role_assignment.radixflowlogsdev]
# }


# resource "azurerm_data_protection_backup_instance_blob_storage" "radixinfradev" {
#   name               = "radixinfradev"
#   vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
#   location           = data.azurerm_resource_group.s941_tfstate.location
#   storage_account_id = data.azurerm_storage_account.radixinfradev.id
#   backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
#   depends_on = [azurerm_role_assignment.radixinfradev]
# }

# resource "azurerm_data_protection_backup_instance_blob_storage" "radixvelerodev" {
#   name               = "radixvelerodev"
#   vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
#   location           = data.azurerm_resource_group.velero_backups.location
#   storage_account_id = data.azurerm_storage_account.radixvelerodev.id
#   backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
#   depends_on = [azurerm_role_assignment.radixvelerodev]
# }

# resource "azurerm_data_protection_backup_instance_blob_storage" "s941sqllogsdev" {
#   name               = "s941sqllogsdev"
#   vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
#   location           = data.azurerm_resource_group.common.location
#   storage_account_id = data.azurerm_storage_account.s941sqllogsdev.id
#   backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
#   depends_on         = [azurerm_role_assignment.s941sqllogsdev]
# }

# resource "azurerm_data_protection_backup_instance_blob_storage" "s941sqllogsplayground" {
#   name               = "s941sqllogsplayground"
#   vault_id           = azurerm_data_protection_backup_vault.azure_backup_vault.id
#   location           = data.azurerm_resource_group.common.location
#   storage_account_id = data.azurerm_storage_account.s941sqllogsplayground.id
#   backup_policy_id   = azurerm_data_protection_backup_policy_blob_storage.backup_policy_dev.id
#   depends_on         = [azurerm_role_assignment.s941sqllogsplayground]
# }



##########################################################################################
# Storage Account

# resource "azurerm_storage_account" "radixspjtest" {
#   name                     = "radixspjtest"
#   resource_group_name      = data.azurerm_resource_group.velero_backups.name
#   location                 = data.azurerm_resource_group.velero_backups.location
#   account_tier             = "Standard"
#   account_replication_type = "RAGRS"
# }

