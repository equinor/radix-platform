module "dns_zone" {
  source               = "../../modules/dns_zone"
  resourcegroup_common = module.resourcegroup_common.data.name
  dnszoneprefix        = "${var.environment}."
}

module "radix-id-certmanager-mi" {
  source              = "../../modules/userassignedidentity"
  name                = "radix-id-certmanager-${var.environment}"
  location            = var.location
  resource_group_name = module.resourcegroup_common.data.name
  roleassignments = {
    role = {
      role     = "DNS TXT Contributor"
      scope_id = module.dns_zone.azurerm_dns_zone_id
    }
  }
}

output "dns_zone_name" {
  value = "${var.environment}.radix.equinor.com"
}