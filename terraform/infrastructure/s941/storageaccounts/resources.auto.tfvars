storage_accounts = {
  "radixazauditlogsdev" = {
    name          = "radixazauditlogsdev"
    rg_name       = "rg-radix-shared-dev"
    backup_center = true
    life_cycle    = false
    # versioning_enabled = true
    # change_feed_enabled = true
    allow_nested_items_to_be_public = true
    location      = "norwayeast"
  }
  "radixflowlogsdev" = {
    name          = "radixflowlogsdev"
    rg_name       = "Logs-Dev"
    backup_center = true
    # life_cycle    = true
    # versioning_enabled = true
    # change_feed_enabled = true
    allow_nested_items_to_be_public = true
  }
  "radixinfradev" = {
    name          = "radixinfradev"
    rg_name       = "s941-tfstate"
    backup_center = true
    # life_cycle    = true
    # versioning_enabled = true
    # change_feed_enabled = true
    repl          = "GRS"
    kind          = "BlobStorage"
    shared_access_key_enabled = false
    container_delete_retention_policy = true
    # allow_nested_items_to_be_public = false
    #delete_retention_policy = true
  }
  "radixvelerodev" = {
    name          = "radixvelerodev"
    rg_name       = "Velero_Backups"
    backup_center = false
    # life_cycle    = true
    # versioning_enabled = true
    # change_feed_enabled = true
    repl          = "GRS"
    kind          = "BlobStorage"
    container_delete_retention_policy = true
    allow_nested_items_to_be_public = true
    delete_retention_policy = true
  }
  "s941sqllogsdev" = {
    name          = "s941sqllogsdev"
    rg_name       = "common"
    backup_center = true
    # life_cycle    = true
    # versioning_enabled = true
    # change_feed_enabled = true
  }
  "s941sqllogsplayground" = {
    name          = "s941sqllogsplayground"
    rg_name       = "common"
    backup_center = true
    # life_cycle    = true
    # versioning_enabled = true
    # change_feed_enabled = true
  }
}