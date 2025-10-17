module "acr" {
  source              = "../../modules/acr"
  location            = var.location
  resource_group_name = module.resourcegroup_common.data.name
  acr                 = var.environment
  vnet_resource_group = module.azurerm_virtual_network.data.vnet_hub.resource_group_name
  subnet_id           = module.azurerm_virtual_network.data.vnet_subnet.id
  keyvault_name       = module.keyvault.vault_name
  radix_cr_cicd       = var.radix_cr_cicd
  secondary_location  = var.secondary_location
  testzone            = var.testzone
  depends_on          = [module.azurerm_virtual_network]
}

output "imageRegistry" {
  value = module.acr.azurerm_container_registry_env_login_server
}