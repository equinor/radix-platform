module "easyauth" {
  count  = var.enable_easyauth ? 1 : 0
  source = "../easyauth"

  environment               = var.easyauth.environment
  location                  = var.location
  resource_group_name       = var.easyauth.resource_group_name
  vnet_resource_group       = var.easyauth.vnet_resource_group
  app_display_name          = var.easyauth.app_display_name
  app_owners                = var.easyauth.app_owners
  allowed_group_names       = var.easyauth.allowed_group_names
  postgres_admin_group_name = var.easyauth.postgres_admin_group_name
  postgres_sku_name         = var.easyauth.postgres_sku_name
}
