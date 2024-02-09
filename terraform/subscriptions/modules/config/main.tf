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
  value = "cluster-vnet-hub-${local.config.environment}"
}
output "key_vault_name" {
  value = "radix-keyv-${local.config.environment}"
}

output "log_analytics_name" {
  value = "radix-logs-${local.config.environment}"
}
output "backend" {
  value = local.config.backend
}

output "policy_aks_diagnostics_cluster" {
  value = "Radix-Enforce-Diagnostics-AKS-Clusters"
}
output "cluster_names" {
  value = local.config.clusters
}
