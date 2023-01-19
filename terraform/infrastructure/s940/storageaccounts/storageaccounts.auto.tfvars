storage_accounts = {
  "backupsstorageaccount" = {
    name                = "backupsstorageaccount"
    rg_name             = "monitoring"
    kind                = "Storage"
    change_feed_enabled = false
    versioning_enabled  = false
    backup_center       = false
    life_cycle          = false
  }
  "costallocationprodsqllog" = {
    name          = "costallocationprodsqllog"
    rg_name       = "cost-allocation"
    backup_center = true
  }
  "radixflowlogsc2prod" = {
    name          = "radixflowlogsc2prod"
    rg_name       = "logs-westeurope"
    location      = "westeurope"
    backup_center = true
    life_cycle    = false
  }
  "radixflowlogsprod" = {
    name          = "radixflowlogsprod"
    rg_name       = "Logs"
    backup_center = true
    life_cycle    = false
  }
  "radixgrafanabackup" = {
    name          = "radixgrafanabackup"
    rg_name       = "monitoring"
    backup_center = true
  }
  "radixsqllogsprod" = {
    name          = "radixsqllogsprod"
    rg_name       = "rg-radix-shared-prod"
    location      = "norwayeast"
    backup_center = true
  }
  "radixveleroc2prod" = {
    name          = "radixveleroc2prod"
    rg_name       = "backups"
    location      = "westeurope"
    repl          = "GRS"
    kind          = "BlobStorage"
    backup_center = false
  }
  "radixveleroprod" = {
    name          = "radixveleroprod"
    rg_name       = "backups"
    repl          = "LRS"
    kind          = "BlobStorage"
    backup_center = false
  }
  "s940radixinfra" = {
    name          = "s940radixinfra"
    rg_name       = "s940-tfstate"
    repl          = "RAGRS"
    backup_center = true
  }
  "s940sqllogsc2prod" = {
    name          = "s940sqllogsc2prod"
    rg_name       = "common-westeurope"
    location      = "westeurope"
    backup_center = true
    life_cycle    = false
  }
  "s940sqllogsprod" = {
    name          = "s940sqllogsprod"
    rg_name       = "common"
    backup_center = true
    life_cycle    = false
  }
}
