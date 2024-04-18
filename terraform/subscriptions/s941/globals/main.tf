module "resourcegroups" {
  for_each = toset(["backups", "common", "Logs-Dev"])

  source   = "../../modules/resourcegroups"
  name     = each.value
  location = module.config.location
}

data "azurerm_subscription" "main" {
  subscription_id = module.config.subscription
}
