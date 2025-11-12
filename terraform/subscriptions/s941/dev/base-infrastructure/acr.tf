module "acr" {
  source               = "../../../modules/acr"
  location             = module.config.location
  resource_group_name  = module.config.common_resource_group
  acr                  = module.config.environment
  vnet_resource_group  = module.config.vnet_resource_group
  subnet_id            = module.azurerm_virtual_network.azurerm_subnet_id
  keyvault_name        = module.keyvault.vault_name
  dockercredentials_id = "/subscriptions/${module.config.subscription}/resourceGroups/${module.config.common_resource_group}/providers/Microsoft.ContainerRegistry/registries/radix${module.config.environment}cache/credentialSets/radix-service-account-docker"
  radix_cr_cicd        = replace(replace(module.app_application_registration.cr_cicd.azuread_service_principal_id, "/servicePrincipals/", ""), "/", "")
  radix_gitrunner      = module.radix_id_gitrunner.client-id
  acr_retension_policy = 1
  secondary_location   = module.config.secondary_location
  depends_on           = [module.azurerm_virtual_network]
  abac_this            = true
  abac_env             = true
  abac_cache           = true
}

output "imageRegistry" {
  value = module.acr.azurerm_container_registry_env_login_server
}
