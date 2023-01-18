storage_accounts = {
  "radixflowlogsdev" = {
    name          = "radixflowlogsdev"
    rg_name       = "Logs-Dev"
    backup_center = true
  }
  "radixinfradev" = {
    name          = "radixinfradev"
    rg_name       = "s941-tfstate"
    backup_center = false
    repl          = "GRS"
    kind          = "BlobStorage"
    shared_access_key_enabled = false
    firewall      = false
  }
  "radixvelerodev" = {
    name          = "radixvelerodev"
    rg_name       = "backups"
    backup_center = false
    repl          = "GRS"
    kind          = "BlobStorage"
  }
  "s941radixinfra" = {
    name          = "s941radixinfra"
    rg_name       = "s941-tfstate"
    backup_center = true
    repl          = "RAGRS"
    allow_nested_items_to_be_public = false
  }
  "s941sqllogsdev" = {
    name          = "s941sqllogsdev"
    rg_name       = "common"
    backup_center = true
  }
  "s941sqllogsplayground" = {
    name          = "s941sqllogsplayground"
    rg_name       = "common"
    backup_center = true
  }
}
