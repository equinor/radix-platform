module "dex_identity" {
  source = "../userassignedidentity"

  name                = "radix-id-easyauth-dex-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
}
