terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_managed_api" "azureblob" {
  name     = "azureblob"
  location = "northeurope"
}

data "azurerm_managed_api" "azuremonitorlogs" {
  name     = "azuremonitorlogs"
  location = "northeurope"
}
# data "azurerm_logic_app_workflow" "example" {
#   name                = "archive-s941-northeurope-diagnostics"
#   resource_group_name = "Logs-Dev"
# }

resource "azurerm_logic_app_workflow" "logic_app_workflow" {
  for_each            = var.logic_app_workflow
  name                = each.value["name"]
  location            = each.value["location"]
  resource_group_name = each.value["rg_name"]
  enabled             = false

  identity {
    identity_ids = [
      "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/radix-github-maintenance-dev"
    ]
    type = "UserAssigned"
  }
# parameters = {
#     "$connections" = {
#         "value": {
#             "teams": {
#                 "connectionId": "...",
#                 "connectionName": "teams",
#                 "id": "..."
#             }
#         }
#     }
# }

  # parameters                      = {
  #       "$connections" = jsonencode(
  #           {
  #               azureblob_1 = {
  #                   connectionId         = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/Logs-Dev/providers/Microsoft.Web/connections/azureblob"
  #                   connectionName       = "azureblob"
  #                   connectionProperties = {
  #                       authentication = {
  #                           identity = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/radix-github-maintenance-dev"
  #                           type     = "ManagedServiceIdentity"
  #                       }
  #                   }
  #                   id                   = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/providers/Microsoft.Web/locations/northeurope/managedApis/azureblob"
  #               }
  #           }
  #       )
  #   }



  # workflow_parameters = {
  #   "azureblob_1" = {
  #     connectionId         = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/Logs-Dev/providers/Microsoft.Web/connections/azureblob"
  #     connectionName       = "azureblob"
  #     connectionProperties = {
  #       authentication = {
  #         identity = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/radix-github-maintenance-dev"
  #         type     = "ManagedServiceIdentity"
  #         }
  #     id                   = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/providers/Microsoft.Web/locations/northeurope/managedApis/azureblob"
  #     default  = "default_value"
  #     metadata = {
  #       description = "Description of parameter1"
  #     }
  #   }

  # }
  # }


  # parameters {
  #   azureblob_1 = {
  #     type  = "string"
  #     connectionId = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/Logs-Dev/providers/Microsoft.Web/connections/azureblob"
  #     # connectionName = "azureblob"
  #     # connectionProperties = {
  #     #   authentication =  {
  #     #     identity = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/radix-github-maintenance-dev"
  #     #     type = "ManagedServiceIdentity"
  #     #   }
  #     # },
  #     #id = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/providers/Microsoft.Web/locations/northeurope/managedApis/azureblob"
  #   }
  # }
  # parameters = {
  #   "connections" = jsonencode(
  #     {
  #       azureblob_1 = {
  #         connectionId   = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/Logs-Dev/providers/Microsoft.Web/connections/azureblob"
  #         connectionName = "azureblob"
  #         connectionProperties = {
  #           authentication = {
  #             identity = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/radix-github-maintenance-dev"
  #             type     = "ManagedServiceIdentity"
  #           }
  #         }
  #         id = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/providers/Microsoft.Web/locations/northeurope/managedApis/azureblob"
  #       }
  #     }
  #   )
  # }
  # parameters = {
  #   "$connections" = jsonencode(
  #     {
  #       azureblob_1 = {
  #         connectionId   = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/Logs-Dev/providers/Microsoft.Web/connections/azureblob"
  #         connectionName = "azureblob"
  #         connectionProperties = {
  #           authentication = {
  #             identity = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/radix-github-maintenance-dev"
  #             type     = "ManagedServiceIdentity"
  #           }
  #         }
  #         id = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/providers/Microsoft.Web/locations/northeurope/managedApis/azureblob"
  #       }
  #       azuremonitorlogs = {
  #         connectionId   = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/Logs-Dev/providers/Microsoft.Web/connections/azuremonitorlogs"
  #         connectionName = "azuremonitorlogs"
  #         connectionProperties = {
  #           authentication = {
  #             identity = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/radix-github-maintenance-dev"
  #             type     = "ManagedServiceIdentity"
  #           }
  #         }
  #         id = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/providers/Microsoft.Web/locations/northeurope/managedApis/azuremonitorlogs"
  #       }
  #     }
  #   )
  # }

}
