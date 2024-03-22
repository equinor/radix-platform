module "config" {
  source = "../../../modules/config"
}

data "azurerm_dns_zone" "this" {
  name                = "dev.radix.equinor.com"
  resource_group_name = "common"
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

output "mi" {
  value = {
    client-id = module.radix-id-certmanager-mi.client-id,
    name      = module.radix-id-certmanager-mi.name
  }
}