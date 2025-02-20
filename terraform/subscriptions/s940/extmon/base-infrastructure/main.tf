module "config" {
  source = "../../../modules/config"
}

data "azurerm_subscription" "current" {}

# data "azuread_group" "sql_admin" {
#   display_name     = "Radix SQL server admin - ${module.config.environment}"
#   security_enabled = true
# }

data "azuread_group" "radix" {
  display_name = "Radix"
}
