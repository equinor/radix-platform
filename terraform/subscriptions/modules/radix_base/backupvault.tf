module "backupvault" {
  source                = "../../modules/backupvaults"
  name                  = "Backupvault-${var.environment}"
  resource_group_name   = module.resourcegroup_common.data.name
  location              = var.location
  policyblobstoragename = "Backuppolicy-blob"
}