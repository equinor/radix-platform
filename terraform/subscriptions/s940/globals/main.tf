data "azurerm_subscription" "main" {
  subscription_id = module.config.subscription
}
