module "radix_id_velero_mi" {
  source              = "../../modules/userassignedidentity"
  name                = "radix-id-velero-${var.environment}"
  location            = var.location
  resource_group_name = module.resourcegroup_common.data.name
  roleassignments = {
    sac_user = {
      role     = "Storage Blob Data Contributor"
      scope_id = module.storageaccount.velero.data.id
    }
  }
}