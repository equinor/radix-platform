resource "azurerm_role_definition" "aso_role" {
  name        = "Radix Azure Service Operator"
  scope       = "/subscriptions/${module.config.subscription}"
  description = "The role Azure Serivce Operator needs to create Private Endpoints"

  permissions {
    actions = [
      "Microsoft.Network/privateEndpoints/read",
      "Microsoft.Network/privateEndpoints/write",
      "Microsoft.Network/privateEndpoints/delete",

      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/join/action",

      // Persmissions to create Private DNS Zone entry:
      "Microsoft.Network/privateDnsZones/join/action",
      "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write",
      "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/read",
      "Microsoft.Network/privateEndpoints/privateDnsZoneGroups/delete",
    ]
  }
}
