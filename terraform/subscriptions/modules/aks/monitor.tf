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

resource "azurerm_monitor_data_collection_rule" "this" {
  name                = var.enviroment == "platform" ? "MSCI-NEU-${var.cluster_name}" : "MSCI-${var.location}-${var.cluster_name}" #"MSCI-${var.location}-${var.cluster_name}" #TODO
  resource_group_name = var.resource_group
  location            = var.location
  kind                = "Linux"
  tags = {
    IaC = "terraform"
  }

  destinations {
    log_analytics {
      name                  = "la-workspace"
      workspace_resource_id = var.containers_workspace_id
    }
  }

  data_flow {
    streams = [
      "Microsoft-ContainerLog",
      "Microsoft-ContainerLogV2",
      "Microsoft-KubeEvents",
      "Microsoft-KubePodInventory",
      "Microsoft-InsightsMetrics",
      "Microsoft-ContainerInventory",
      "Microsoft-ContainerNodeInventory",
      "Microsoft-KubeNodeInventory",
      "Microsoft-KubeServices"
    ]
    destinations = ["la-workspace"]
  }

  data_sources {
    extension {
      name = "ContainerInsightsExtension"
      streams = [
        "Microsoft-ContainerLog",
        "Microsoft-ContainerLogV2",
        "Microsoft-KubeEvents",
        "Microsoft-KubePodInventory",
        "Microsoft-InsightsMetrics",
        "Microsoft-ContainerInventory",
        "Microsoft-ContainerNodeInventory",
        "Microsoft-KubeNodeInventory",
        "Microsoft-KubeServices"
      ]
      extension_name = "ContainerInsights"
      extension_json = jsonencode({
        dataCollectionSettings = {
          enableContainerLogV2   = true
          interval               = var.enviroment == "dev" || var.enviroment == "playground" || var.enviroment == "extmon" ? "5m" : "1m"
          namespaceFilteringMode = "Exclude"
          streams = [
            "Microsoft-ContainerLog",
            "Microsoft-ContainerLogV2",
            "Microsoft-KubeEvents",
            "Microsoft-KubePodInventory",
            "Microsoft-InsightsMetrics",
            "Microsoft-ContainerInventory",
            "Microsoft-ContainerNodeInventory",
            "Microsoft-KubeNodeInventory",
            "Microsoft-KubeServices"
          ]
          namespaces = [
            "kube-system",
            "gatekeeper-system",
            "azure-arc"
          ]
        }
      })
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "this" {
  name                    = azurerm_kubernetes_cluster.this.name
  target_resource_id      = azurerm_kubernetes_cluster.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.this.id
}
