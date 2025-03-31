data "azurerm_container_registry" "cache" {
  name                = "radixplatformcache"
  resource_group_name = "common-platform"
}


module "radix_id_akskubelet_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-akskubelet-${module.config.environment}"
  location            = module.config.location
  resource_group_name = module.resourcegroup_common.data.name
  roleassignments = {
    arccache = {
      role     = "AcrPull"
      scope_id = data.azurerm_container_registry.cache.id
    }
  }
}

module "radix_id_aks_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-aks-${module.config.environment}"
  location            = module.config.location
  resource_group_name = module.resourcegroup_common.data.name
  roleassignments = {
    mi_operator = {
      role     = "Managed Identity Operator"
      scope_id = module.radix_id_akskubelet_mi.data.id
    }
    rg_cluster = {
      role     = "Contributor"
      scope_id = module.resourcegroup_clusters.data.id
    }
  }
}
