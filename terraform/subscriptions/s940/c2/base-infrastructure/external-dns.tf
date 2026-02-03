module "radix_id_externaldns_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-external-dns-${module.config.environment}"
  location            = module.config.location
  resource_group_name = module.resourcegroup_common.data.name
  roleassignments = {
    mi_akskubelet = {
      role     = "DNS TXT Contributor"
      scope_id = module.dns_zone.azurerm_dns_zone_id
    }
  }
}

output "radix-id-external-dns" {
  value       = module.radix_id_externaldns_mi.client-id
  sensitive   = true
  description = "client-id for mi"
  depends_on  = []
}
