resource "azurerm_monitor_diagnostic_setting" "this" {
  name               = "Radix-Diagnostics"
  target_resource_id = azurerm_kubernetes_cluster.this.id
  storage_account_id = var.storageaccount_id

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-apiserver"
  }

  metric {
    category = "AllMetrics"
    enabled  = false
  }

}