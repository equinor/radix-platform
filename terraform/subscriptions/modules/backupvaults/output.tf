output "data" {
  description = "The ID of backupvaults."
  value = {
    "backupvault"       = azurerm_data_protection_backup_vault.backupvault
    "policyblobstorage" = azurerm_data_protection_backup_policy_blob_storage.policyblobstorage
  }
}
