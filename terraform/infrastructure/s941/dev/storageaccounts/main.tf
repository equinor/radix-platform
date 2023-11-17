terraform {
  # backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_subscription" "AZ_SUBSCRIPTION" {
  subscription_id = var.AZ_SUBSCRIPTION_ID
}

locals {
  WHITELIST_IPS = jsondecode(textdecodebase64("${data.azurerm_key_vault_secret.whitelist_ips.value}", "UTF-8"))
  storageaccount_private_subnet = merge([for sa_key, sa_value in var.storage_accounts : {
    for privlink_key, privlink_value in var.private_link :
    "${sa_key}-${privlink_key}" => {
      name                = sa_value.name
      resource_group_name = sa_value.rg_name
      location            = sa_value.location
      subnet_id           = privlink_value.linkname
      private_endpoint    = sa_value.private_endpoint
    }
  }]...)
  privatelink_dns_record = merge([for sa_key, sa_value in var.storage_accounts : {
    for virtual_networks_key, virtual_networks_value in var.virtual_networks :
    "${sa_key}-${virtual_networks_key}" => {
      name                = sa_value.name
      resource_group_name = virtual_networks_value.rg_name
      private_endpoint    = sa_value.private_endpoint
    }
  }]...)
}

data "azurerm_key_vault" "keyvault_env" {
  name                = var.KV_RADIX_VAULT
  resource_group_name = var.AZ_RESOURCE_GROUP_COMMON
}

data "azurerm_key_vault_secret" "whitelist_ips" {
  name         = "acr-whitelist-ips-${var.RADIX_ZONE}"
  key_vault_id = data.azurerm_key_vault.keyvault_env.id
}

data "azurerm_subnet" "virtual_subnets" {
  for_each             = { for key, value in var.resource_groups : key => value if length(regexall("cluster-vnet-hub", key)) > 0 }
  name                 = "private-links"
  virtual_network_name = "vnet-hub"
  resource_group_name  = each.value["name"]
}

data "azurerm_private_dns_zone" "dns-zone" {
  for_each            = { for key, value in var.resource_groups : key => value if length(regexall("cluster-vnet-hub", key)) > 0 }
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = each.value["name"]
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
### Private endpoint
###

resource "azurerm_private_endpoint" "northeurope" {
  for_each            = { for key in compact([for key, value in local.storageaccount_private_subnet : value.location == var.AZ_LOCATION && value.private_endpoint ? key : ""]) : key => local.storageaccount_private_subnet[key] }
  name                = each.key
  resource_group_name = each.value["resource_group_name"]
  location            = each.value["location"]
  subnet_id           = each.value["subnet_id"]
  depends_on          = [azurerm_storage_account.storageaccounts]

  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_storage_account.storageaccounts[each.value["name"]].id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

}

## DNS 
resource "azurerm_private_dns_a_record" "dns_a_northeurope" {
  for_each            = { for key in compact([for key, value in local.privatelink_dns_record : value.private_endpoint ? key : ""]) : key => local.privatelink_dns_record[key] }
  name                = each.value["name"]
  zone_name           = "privatelink.blob.core.windows.net"
  resource_group_name = each.value["resource_group_name"]
  ttl                 = 10
  records             = [azurerm_private_endpoint.northeurope[each.key].private_service_connection.0.private_ip_address]
  depends_on          = [azurerm_private_endpoint.northeurope]
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
  depends_on         = [azurerm_storage_account.storageaccounts]

  rule {
    name    = "lifecycle-${var.RADIX_ZONE}"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      dynamic "version" {
        for_each = each.value["life_cycle_version"] != 0 ? [60] : []
        content {
          delete_after_days_since_creation = each.value["life_cycle_version"]
        }
      }

      dynamic "base_blob" {
        for_each = each.value["life_cycle_blob"] != 0 ? [180] : []
        content {
          delete_after_days_since_modification_greater_than       = each.value["life_cycle_blob"]
          tier_to_cool_after_days_since_modification_greater_than = each.value["life_cycle_blob_cool"]
        }
      }
    }
  }
}

#######################################################################################
### Protection Vault
###

resource "azurerm_data_protection_backup_vault" "northeurope" {
  name                = "${var.AZ_SUBSCRIPTION_SHORTNAME}-backupvault-${var.AZ_LOCATION}"
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
  name               = "${var.AZ_SUBSCRIPTION_SHORTNAME}-backuppolicy-${var.AZ_LOCATION}"
  vault_id           = azurerm_data_protection_backup_vault.northeurope.id
  retention_duration = "P30D"
}
