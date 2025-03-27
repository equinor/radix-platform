data "azurerm_storage_account" "this" {
  name                = "radixlog${module.config.environment}"
  resource_group_name = module.config.common_resource_group
}

data "http" "public_ip" {
  url = "https://ifconfig.me/ip"
}