output "istio_rules" {
  description = "Map of istio security rules"
  value       = azurerm_network_security_rule.istio
}

output "ssh_rules" {
  description = "Map of SSH deny rules"
  value       = azurerm_network_security_rule.ssh
}
