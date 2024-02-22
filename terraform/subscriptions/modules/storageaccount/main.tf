# #######################################################################################
# ### Storage Account
# ###

resource "azurerm_storage_account" "storageaccount" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_kind             = var.kind
  account_replication_type = var.account_replication_type
  account_tier             = var.tier
  dynamic "blob_properties" {
    for_each = var.kind == "BlobStorage" || var.kind == "Storage" ? [1] : []
    content {
      change_feed_enabled           = var.change_feed_enabled
      versioning_enabled            = var.versioning_enabled
      change_feed_retention_in_days = var.change_feed_retention_in_days

      dynamic "container_delete_retention_policy" {
        for_each = var.container_delete_retention_policy == true ? [30] : []
        content {
          days = container_delete_retention_policy.value
        }
      }
      dynamic "delete_retention_policy" {
        for_each = var.delete_retention_policy == true ? [35] : []

        content {
          days = delete_retention_policy.value
        }
      }
      dynamic "restore_policy" {
        for_each = var.backup_center == true ? [30] : []

        content {
          days = restore_policy.value
        }
      }
    }
  }

  tags = {
    environment = var.environment
  }
}

# #######################################################################################
# ### Role assignment from Backup Vault to Storage Account
# ###

resource "azurerm_role_assignment" "roleassignment" {
  for_each = var.backup && var.kind == "StorageV2" ? { "${var.name}" : true } : {}

  scope                = azurerm_storage_account.storageaccount.id
  role_definition_name = "Storage Account Backup Contributor"
  principal_id         = var.principal_id
  depends_on           = [azurerm_storage_account.storageaccount]
}

# #######################################################################################
# ### Role assignment for Velero Service Principal to be used to the Storage account
# ###

data "azuread_service_principal" "velero" { # wip To be changed to workload identity in the future
  display_name = var.velero_service_principal
}

resource "azurerm_role_assignment" "storage_blob_data_conntributor" {
  for_each             = can(regex("radixvelero.*", var.name)) ? { "${var.name}" : true } : {}
  scope                = azurerm_storage_account.storageaccount.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = data.azuread_service_principal.velero.id
  depends_on           = [azurerm_storage_account.storageaccount]
}

######################################################################################
## Blob Protection
##

resource "azurerm_data_protection_backup_instance_blob_storage" "backupinstanceblobstorage" {
  for_each           = var.backup && var.kind == "StorageV2" ? { "${var.name}" : true } : {}
  name               = azurerm_storage_account.storageaccount.name
  vault_id           = var.vault_id
  location           = var.location
  storage_account_id = azurerm_storage_account.storageaccount.id
  backup_policy_id   = var.policyblobstorage_id
  depends_on         = [azurerm_role_assignment.roleassignment]
}

resource "azurerm_storage_account_network_rules" "this" {
  # for_each                   = var.firewall ? { "${var.name}" : true } : {}
  storage_account_id = azurerm_storage_account.storageaccount.id
  default_action     = "Deny"
  ip_rules           = []
  # virtual_network_subnet_ids = [var.subnet_id]

}

data "azurerm_subnet" "subnet" {
  name                 = "private-links"
  virtual_network_name = var.virtual_network
  resource_group_name  = var.vnet_resource_group
}
resource "azurerm_private_endpoint" "this" {
  name                = "pe-${var.name}"
  location            = var.location
  resource_group_name = var.vnet_resource_group
  subnet_id           = data.azurerm_subnet.subnet.id
  depends_on          = [azurerm_storage_account.storageaccount]

  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_storage_account.storageaccount.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
}
resource "azurerm_private_dns_a_record" "this" {
  name                = azurerm_storage_account.storageaccount.name
  zone_name           = "privatelink.blob.core.windows.net"
  resource_group_name = var.vnet_resource_group
  ttl                 = 60
  records             = [azurerm_private_endpoint.this.private_service_connection.0.private_ip_address]
}

resource "azurerm_storage_management_policy" "this" {
  storage_account_id = azurerm_storage_account.storageaccount.id
  rule {
    name    = "lifecycle-blockblob"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      version {
        delete_after_days_since_creation = 60
      }
      base_blob {
        delete_after_days_since_modification_greater_than       = 90
        tier_to_cool_after_days_since_modification_greater_than = 30
      }
    }
  }
  depends_on = [azurerm_storage_account.storageaccount]
}



