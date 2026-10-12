module "radix-id-acr-cleanup-mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-acr-cleanup-${module.config.environment}"
  location            = module.config.location
  resource_group_name = module.resourcegroup_common.data.name
  roleassignments = {
    role = {
      role     = "Contributor"
      scope_id = module.acr.azurerm_container_registry_id
    }
  }
  depends_on = [module.acr]
}

output "radix_id_acr_cleanup_mi_client_id" {
  value = module.radix-id-acr-cleanup-mi.data.client_id
}
