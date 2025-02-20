data "azurerm_dns_zone" "this" {
  name                = "c2.radix.equinor.com"
  resource_group_name = "common-westeurope"
}

module "radix-id-certmanager-mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-certmanager-${module.config.environment}"
  location            = module.config.location
  resource_group_name = module.config.common_resource_group
  roleassignments = {
    role = {
      role     = "DNS TXT Contributor"
      scope_id = data.azurerm_dns_zone.this.id
    }
  }
}