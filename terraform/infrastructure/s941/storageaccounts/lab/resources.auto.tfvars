storage_accounts = {
  "jobdemostorage" = {
    name          = "jobdemostorage"
    rg_name       = "test-resources"
    cross_tenant_replication_enabled = false
    backup_center = true
    life_cycle    = false
    # versioning_enabled = true
    # change_feed_enabled = true
    #allow_nested_items_to_be_public = true
  }
}
