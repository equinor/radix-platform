module "acr" {
  source               = "../../../modules/acr"
  location             = module.config.location
  resource_group_name  = module.resourcegroup_common.data.name
  acr                  = "prod" #TODO
  vnet_resource_group  = module.azurerm_virtual_network.data.vnet_hub.resource_group_name
  subnet_id            = module.azurerm_virtual_network.data.vnet_subnet.id
  keyvault_name        = module.keyvault.vault_name
  dockercredentials_id = "/subscriptions/${module.config.subscription}/resourceGroups/${module.config.common_resource_group}/providers/Microsoft.ContainerRegistry/registries/radix${module.config.environment}cache/credentialSets/radix-service-account-docker"
  radix_cr_cicd        = replace(replace(module.app_application_registration.cr_cicd.azuread_service_principal_id, "/servicePrincipals/", ""), "/", "")
  secondary_location   = module.config.secondary_location
  depends_on           = [module.azurerm_virtual_network]
  abac_this            = false
  abac_env             = false
  abac_cache           = false
}

output "imageRegistry" {
  value = module.acr.azurerm_container_registry_env_login_server
}