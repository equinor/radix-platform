# #######################################################################################
# ### Storage Account
# ###

resource "azurerm_storage_account" "storageaccount" {
  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_kind                    = var.kind
  account_replication_type        = var.account_replication_type
  account_tier                    = var.tier
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  public_network_access_enabled   = true
  shared_access_key_enabled       = var.shared_access_key_enabled


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
    IaC = "terraform"
  }
}

resource "azurerm_role_assignment" "roleassignment" {
  for_each = var.backup && var.kind == "StorageV2" ? { "${var.name}" : true } : {}

  scope                = azurerm_storage_account.storageaccount.id
  role_definition_name = "Storage Account Backup Contributor"
  principal_id         = var.principal_id
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
  storage_account_id = azurerm_storage_account.storageaccount.id
  default_action     = "Deny"
  ip_rules           = []

}