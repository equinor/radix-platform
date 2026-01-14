output "active_records" {
  description = "Active DNS records created"
  value       = azurerm_dns_a_record.active
}

output "cluster_records" {
  description = "Cluster-specific DNS records"
  value       = azurerm_dns_a_record.cluster
}

output "extmon_records" {
  description = "Extmon DNS records"
  value       = azurerm_dns_a_record.extmon
}
