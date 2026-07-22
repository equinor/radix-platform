variable "configfile" {
  type    = string
  default = "../config.yaml"
}

variable "private_dns_zone_names" {
  description = "Private DNS zone names with optional resolution policies. Default is Default unless explicitly overridden."
  type = map(object({
    resolution_policy = optional(string, "Default") # Valid values: Default, NxDomainRedirect
  }))
  default = {
    "private.radix.equinor.com"                   = {}
    "privatelink.azconfig.io"                     = {}
    "privatelink.azurecr.io"                      = {}
    "privatelink.blob.core.windows.net"           = {}
    "privatelink.cassandra.cosmos.azure.com"      = {}
    "privatelink.cognitiveservices.azure.com"     = {}
    "privatelink.database.windows.net"            = { resolution_policy = "NxDomainRedirect" }
    "privatelink.dfs.core.windows.net"            = {}
    "privatelink.documents.azure.com"             = {}
    "privatelink.file.core.windows.net"           = {}
    "privatelink.gremlin.cosmos.azure.com"        = {}
    "privatelink.mariadb.database.azure.com"      = {}
    # "privatelink.monitor.azure.com"             = {} # Read this first: https://techcommunity.microsoft.com/t5/fasttrack-for-azure/how-azure-monitor-s-implementation-of-private-link-differs-from/ba-p/3608938
    "privatelink.mongo.cosmos.azure.com"          = {}
    "privatelink.mysql.database.azure.com"        = {}
    "privatelink.openai.azure.com"                = {}
    "privatelink.postgres.cosmos.azure.com"       = {}
    "privatelink.postgres.database.azure.com"     = {}
    "privatelink.queue.core.windows.net"          = {}
    "privatelink.radix.equinor.com"               = {}
    "privatelink.redis.cache.windows.net"         = {}
    "privatelink.redisenterprise.cache.azure.net" = {}
    "privatelink.services.ai.azure.com"           = {}
    "privatelink.servicebus.windows.net"          = {}
    "privatelink.table.core.windows.net"          = {}
    "privatelink.table.cosmos.azure.com"          = {}
    "privatelink.vaultcore.azure.net"             = {}
    "privatelink.web.core.windows.net"            = {}
    "privatelink.northeurope.kusto.windows.net"   = {}
    "privatelink.westeurope.kusto.windows.net"    = {}
    "privatelink.swedencentral.kusto.windows.net" = {}
    "privatelink.redis.azure.net"                 = {}
    "privatelink.notebooks.azure.net"             = {}
    "privatelink.api.azureml.ms"                  = {}
  }
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

# TODO: Remove - unused output
# output "cluster_type" {
#   value = local.config.cluster_type
# }

output "common_resource_group" {
  value = "common-${local.config.environment}"
}
output "cluster_resource_group" {
  value = "clusters-${local.config.environment}"
}
output "public_ip_resource_group" {
  value = lookup(lookup(local.config, "network", {}), "public_ip_resource_group", null)
}
output "vnet_resource_group" {
  value = local.config.network.vnet_hub_resourcegroup
}
output "key_vault_name" {
  value = "radix-keyv-${local.config.environment}"
}

# TODO: Remove - unused output
# output "log_analytics_name" {
#   value = "radix-logs-${local.config.environment}"
# }

output "log_storageaccount_name" {
  value = "radixlog${local.config.environment}"
}
output "backend" {
  value = local.config.backend
}

# TODO: Remove - unused output
# output "zoneconfig" {
#   value = local.config.zoneconfig
# }

output "subscription" {
  value = local.config.backend.subscription_id
}

output "subscription_shortname" {
  value = local.config.subscription_shortname
}

# TODO: Remove - unused output
# output "policy_aks_diagnostics_cluster" {
#   value = "Radix-Enforce-Diagnostics-AKS-Clusters"
# }

output "grafana_ar_reader_display_name" {
  value       = "radix-ar-grafana-logreader-extmon"
  description = "App Registration created in tenant/entra/grafana.tf. Used by grafana to query Log Analytics Workspaces"
}

output "private_dns_zones_names" {
  value = var.private_dns_zone_names
}

output "radix_log_api_mi_name" {
  value = "radix-id-log-api-${local.config.environment}"
}

output "developers" {
  value = lookup(local.config, "developers", null)
}

output "cluster" {
  value = lookup(local.config, "clusters", null)
}

# TODO: Remove - unused output
# output "network" {
#   value = lookup(local.config, "network", {})
# }

output "networksets" {
  value = lookup(local.config, "networksets", null)
}

output "ar-radix-servicenow-proxy-client" {
  value = "69031e2e-2341-4116-9dff-236fd906514b"
}

# TODO: Remove - unused output
# output "ar-radix-servicenow-proxy-server" {
#   value = "a898a8fa-b030-4783-9d5b-5ebcdeebdc59"
# }

output "secondary_location" {
  value = lookup(local.config, "secondary_location", false)
}

# TODO: Remove - unused output
# output "testzone" {
#   value = lookup(local.config, "testzone", false)
# }

output "subscription_contributor" {
  value = local.config.subscription_contributor
}

output "legal_owners" {
  value = local.config.legal_owners
}

output "dns_zone_name" {
  value = local.config.dnsZone.name
}

output "dns_zone_create_caa_records" {
  value = lookup(local.config.dnsZone, "create_caa_records", false)
}