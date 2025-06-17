module "radix_id_akskubelet_mi" {
  source              = "../../modules/userassignedidentity"
  name                = "radix-id-akskubelet-${var.environment}" # template
  location            = var.location
  resource_group_name = module.resourcegroup_common.data.name
  roleassignments = {
    arcpull = {
      role     = "AcrPull"
      scope_id = module.acr.azurerm_container_registry_id
    }
    arccache = {
      role     = "AcrPull"
      scope_id = module.acr.azurerm_container_registry_cache_id
    }
  }
}

module "radix_id_aks_mi" {
  source              = "../../modules/userassignedidentity"
  name                = "radix-id-aks-${var.environment}" # template
  location            = var.location
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


