moved {
  from = module.keyvault.azurerm_key_vault.config
  to   = azurerm_key_vault.config
}

moved {
  from = module.config_keyvault_resource_group[0]
  to   = module.config_common_resource_group[0]
}

moved {
  from = module.config_common_resource_group[0]
  to   = module.common_resource_group[0]
}

moved {
  from = module.common_resource_group[0]
  to   = module.common_resource_group["common-c1"]
}
