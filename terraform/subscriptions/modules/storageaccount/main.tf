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
  for_each = {
    for key in compact([for key, value in local.flattened_roleassignment : value.backup && value.kind == "StorageV2" ? key : ""]) : key =>
    local.flattened_roleassignment[key]
  }
  scope                = azurerm_storage_account.storageaccount.id
  role_definition_name = each.key
  principal_id         = var.principal_id
  depends_on           = [azurerm_storage_account.storageaccount]
}

######################################################################################
## Blob Protection
##

resource "azurerm_data_protection_backup_instance_blob_storage" "backupinstanceblobstorage" {
  for_each           = { for key in compact([for key, value in local.flattened_roleassignment : value.backup && value.kind == "StorageV2" ? key : ""]) : key => local.flattened_roleassignment[key] }
  name               = azurerm_storage_account.storageaccount.name
  vault_id           = var.vault_id
  location           = var.location
  storage_account_id = azurerm_storage_account.storageaccount.id
  backup_policy_id   = var.policyblobstorage_id
  depends_on         = [azurerm_role_assignment.roleassignment]
}

######################################################################################
## Private Link
##

resource "azurerm_private_endpoint" "this" {
  for_each            = var.private_endpoint ? { "this" : "true" } : {}
  name                = azurerm_storage_account.storageaccount.name
  resource_group_name = azurerm_storage_account.storageaccount.resource_group_name
  location            = azurerm_storage_account.storageaccount.location
  subnet_id           = var.subnet_id
  depends_on          = [azurerm_storage_account.storageaccount]

  private_service_connection {
    name                           = "Private_Service_Connection"
    private_connection_resource_id = azurerm_storage_account.storageaccount.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
}


######################################################################################
## Private DNS
##
resource "azurerm_private_dns_a_record" "this" {
  for_each            = var.private_endpoint ? { "this" : "true" } : {}
  name                = azurerm_storage_account.storageaccount.name
  zone_name           = "privatelink.blob.core.windows.net"
  resource_group_name = var.vnethub_resource_group
  ttl                 = 10
  records             = ["10.0.0.16"]
  # depends_on          = [azurerm_private_endpoint.this]
}

