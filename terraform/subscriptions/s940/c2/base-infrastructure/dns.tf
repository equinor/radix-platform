module "dns_zone" {
  source               = "../../../modules/dns_zone"
  resourcegroup_common = module.resourcegroup_common.data.name
  dnszone              = module.config.dns_zone_name
  create_caa_records   = module.config.dns_zone_create_caa_records
}

output "dns_zone_name" {
  value = module.config.dns_zone_name
}

output "dns_zone_resource_group" {
  value = module.dns_zone.azurerm_dns_resource_group_name
}
