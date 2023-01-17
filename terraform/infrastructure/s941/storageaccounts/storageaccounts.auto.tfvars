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
    ip_rule       = ["213.236.148.45", "85.19.71.228", "143.97.110.1", "143.97.2.129", "143.97.2.35", "89.8.223.195", "46.9.11.90", "92.220.195.12", "92.221.72.153", "92.221.167.86", "92.221.23.247", "92.221.74.49", "92.221.25.155"]
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
