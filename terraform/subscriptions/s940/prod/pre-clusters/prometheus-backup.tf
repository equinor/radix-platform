data "azurerm_user_assigned_identity" "prometheus_backup" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-prometheus-backup-${module.config.environment}"
}

module "prometheus_backup_mi_fedcred" {
  source              = "../../../modules/federated-credentials"
  for_each            = local.oidc_issuer_urls
  name                = "k8s-prometheus-backup-${each.key}-${module.config.environment}"
  issuer              = each.value
  subject             = "system:serviceaccount:monitor:prometheus-backup-uploader"
  parent_id           = data.azurerm_user_assigned_identity.prometheus_backup.id
  resource_group_name = data.azurerm_user_assigned_identity.prometheus_backup.resource_group_name
  depends_on          = [module.aks]
}
