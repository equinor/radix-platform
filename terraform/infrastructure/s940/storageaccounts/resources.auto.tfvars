storage_accounts = {
  # "backupsstorageaccount" = {
  #   name          = "backupsstorageaccount"
  #   rg_name       = "monitoring"
  #   kind          = "Storage"
  # }
  "costallocationprodsqllog" = {
    name          = "costallocationprodsqllog"
    rg_name       = "cost-allocation"
    life_cycle    = true
    backup_center = true
  }
  "radixflowlogsc2prod" = {
    name          = "radixflowlogsc2prod"
    rg_name       = "logs-westeurope"
    location      = "westeurope"
    #backup_center = true
  }
  "radixflowlogsprod" = {
    name          = "radixflowlogsprod"
    rg_name       = "Logs"
    #backup_center = true
  }
  "radixgrafanabackup" = {
    name          = "radixgrafanabackup"
    rg_name       = "monitoring"
    #backup_center = true
    life_cycle    = true
  }
  "radixsqllogsprod" = {
    name          = "radixsqllogsprod"
    rg_name       = "rg-radix-shared-prod"
    location      = "norwayeast"
    life_cycle    = true
    #backup_center = true
  }
  "radixveleroc2prod" = {
    name          = "radixveleroc2prod"
    rg_name       = "backups"
    location      = "westeurope"
    repl          = "GRS"
    kind          = "BlobStorage"
  }
  "radixveleroprod" = {
    name          = "radixveleroprod"
    rg_name       = "backups"
    repl          = "LRS"
    kind          = "BlobStorage"
  }
  "s940sqllogsc2prod" = {
    name          = "s940sqllogsc2prod"
    rg_name       = "common-westeurope"
    location      = "westeurope"
    #backup_center = true
  }
  "s940sqllogsprod" = {
    name          = "s940sqllogsprod"
    rg_name       = "common"
    #backup_center = true
  }
}