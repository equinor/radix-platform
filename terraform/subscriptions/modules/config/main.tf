variable "configfile" {
  type    = string
  default = "../config.yaml"
}

locals {
  config = yamldecode(file(var.configfile))
}

output "environment" {
  value = local.config.environment
}

output "location" {
  value = local.config.location
}

output "common_resource_group" {
  value = "common-${local.config.environment}"
}
output "cluster_resource_group" {
  value = "clusters-${local.config.environment}"
}
output "vnet_resource_group" {
  # Todo: Create platform resources next time eu18 is recreated
  # Todo: Also fix terraform/subscriptions/modules/mssqldatabase/networking.tf
  value = "cluster-vnet-hub-${local.config.environment == "platform" ? "prod" : local.config.environment}"
}
output "key_vault_name" {
  value = "radix-keyv-${local.config.environment}"
}

output "log_analytics_name" {
  value = "radix-logs-${local.config.environment}"
}
output "log_storageaccount_name" {
  value = "radixlog${local.config.environment}"
}
output "backend" {
  value = local.config.backend
}
output "subscription" {
  value = local.config.backend.subscription_id
}

output "subscription_shortname" {
  value = local.config.subscription_shortname
}

output "policy_aks_diagnostics_cluster" {
  value = "Radix-Enforce-Diagnostics-AKS-Clusters"
}

output "grafana_ar_reader_display_name" {
  value       = "radix-ar-grafana-logreader-extmon"
  description = "App Registration created in tenant/entra/grafana.tf. Used by grafana to query Log Analytics Workspaces"
}

output "private_dns_zones_names" {
  value = [
    "private.radix.equinor.com",
    "privatelink.azconfig.io",
    "privatelink.azurecr.io",
    "privatelink.blob.core.windows.net",
    "privatelink.cassandra.cosmos.azure.com",
    "privatelink.database.windows.net",
    "privatelink.dfs.core.windows.net",
    "privatelink.documents.azure.com",
    "privatelink.file.core.windows.net",
    "privatelink.gremlin.cosmos.azure.com",
    "privatelink.mariadb.database.azure.com",
    #"privatelink.monitor.azure.com", Read this first: https://techcommunity.microsoft.com/t5/fasttrack-for-azure/how-azure-monitor-s-implementation-of-private-link-differs-from/ba-p/3608938
    "privatelink.mongo.cosmos.azure.com",
    "privatelink.mysql.database.azure.com",
    "privatelink.postgres.cosmos.azure.com",
    "privatelink.postgres.database.azure.com",
    "privatelink.queue.core.windows.net",
    "privatelink.radix.equinor.com",
    "privatelink.table.core.windows.net",
    "privatelink.table.cosmos.azure.com",
    "privatelink.vaultcore.azure.net",
    "privatelink.web.core.windows.net",
    "privatelink.redis.cache.windows.net"
  ]
}

output "radix_log_api_mi_name" {
  value = "radix-id-log-api-${local.config.environment}"
}

output "developers" {
  value = local.config.developers
}

output "cluster" {
  value = local.config.clusters
}

output "networksets" {
  value = local.config.networksets
}

output "ar-radix-servicenow-proxy-client" {
  value = "69031e2e-2341-4116-9dff-236fd906514b"
}

output "ar-radix-servicenow-proxy-server" {
  value = "a898a8fa-b030-4783-9d5b-5ebcdeebdc59"
}