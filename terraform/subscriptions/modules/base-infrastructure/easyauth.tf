module "easyauth" {
  count  = var.easyauth != null ? 1 : 0
  source = "../easyauth"

  location                  = var.location
  resource_group_name       = var.common_resource_group
  app_display_name          = var.easyauth.app_display_name
  app_owners                = var.easyauth.app_owners
  allowed_group_names       = var.easyauth.allowed_group_names
  dex_mi_name               = var.easyauth.dex_mi_name
  vnet_resource_group       = var.vnet_resource_group
  postgres_server_name      = var.easyauth.postgres_server_name
  postgres_admin_group_name = var.easyauth.postgres_admin_group_name
  postgres_sku_name         = var.easyauth.postgres_sku_name
  postgres_version          = var.easyauth.postgres_version
  postgres_storage_mb       = var.easyauth.postgres_storage_mb
}
