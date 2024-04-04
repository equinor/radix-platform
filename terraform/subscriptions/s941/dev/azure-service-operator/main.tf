module "config" {
  source = "../../../modules/config"
}

data "azurerm_resource_group" "group" {
  name = module.config.vnet_resource_group
}

# https://azure.github.io/azure-service-operator/guide/authentication/reducing-access/#using-a-credential-for-aso-with-reduced-permissions
# https://learn.microsoft.com/en-us/azure/private-link/
# https://learn.microsoft.com/en-us/azure/private-link/create-private-endpoint-template
# https://learn.microsoft.com/nb-no/azure/role-based-access-control/permissions/networking#microsoftnetwork
resource "azurerm_role_definition" "aso_role" {
  name        = "Radix Azure Service Operator"
  scope       = "/subscriptions/${module.config.subscription}"
  description = "The role Azure Serivce Operator needs to create Private Endpoints"

  permissions {
    actions = [
      "Microsoft.Network/privateEndpoints/*",
      # "Microsoft.Network/networkInterfaces", # Maybe this is required?
      # "Microsoft.Network/virtualNetworks", # Maybe we need access to create private NICs?
      # "Microsoft.Network/virtualNetworks/subnets",
    ]
    not_actions = [
      "Microsoft.Network/dnszones/*" # Private endpoints granted this access as well automatically... lets remove it
    ]
  }
}

module "mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-azure-service-operator-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  location            = module.config.location
}

resource "azurerm_role_assignment" "this" {
  scope              = data.azurerm_resource_group.group.id
  role_definition_id = azurerm_role_definition.aso_role.role_definition_id
  principal_id       = module.mi.principal_id
}
