resource "azurerm_policy_definition" "policy_aks_cluster" {
  name         = "Radix-Enforce-Diagnostics-AKS-Clusters"
  mode         = "All"
  policy_type  = "Custom"
  display_name = "Radix-Enforce-Diagnostics-AKS-Clusters"
  parameters   = jsonencode(
    {
      diagnosticSettingsName = {
        defaultValue = "setByRadixPolicy"
        metadata = {
          description = "Name of the diagnostic settings."
          displayName = "Setting name"
        }
        type = "String"
      }
      logsEnabled = {
        defaultValue = [
          "kube-audit",
        ]
        metadata = {
          description = "Logs enabled"
          displayName = "logsEnabled"
        }
        type = "Array"
      }
      workspaceIdFromAssignment = {
        defaultValue = ""
        metadata = {
          description = "workspaceid From Assignment."
          displayName = "workspaceIdFromAssignment"
        }
        type = "String"
      }
    }
  )
  policy_rule = jsonencode(
    {
      if = {
        equals = "Microsoft.ContainerService/managedClusters"
        field  = "type"
      }
      then = {
        details = {
          deployment = {
            properties = {
              mode = "incremental"
              parameters = {
                diagnosticSettingsName = {
                  value = "[parameters('diagnosticSettingsName')]"
                }
                location = {
                  value = "[field('location')]"
                }
                logsEnabled = {
                  value = "[parameters('logsEnabled')]"
                }
                resourceName = {
                  value = "[field('name')]"
                }
                workspaceIdFromAssignment = {
                  value = "[parameters('workspaceIdFromAssignment')]"
                }
              }
              template = {
                "$schema"      = "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#"
                contentVersion = "1.0.0.0"
                outputs = {}
                parameters = {
                  diagnosticSettingsName = {
                    type = "string"
                  }
                  location = {
                    type = "string"
                  }
                  logsEnabled = {
                    type = "array"
                  }
                  resourceName = {
                    type = "string"
                  }
                  workspaceIdFromAssignment = {
                    type = "string"
                  }
                }
                resources = [
                  {
                    apiVersion = "2017-05-01-preview"
                    dependsOn  = []
                    location   = "[parameters('location')]"
                    name       = "[concat(parameters('resourceName'), '/', 'Microsoft.Insights/', parameters('diagnosticSettingsName'))]"
                    properties = {
                      copy = [
                        {
                          count = "[length(parameters('logsEnabled'))]"
                          input = {
                            category = "[parameters('logsEnabled')[copyIndex('logs')]]"
                            enabled  = true
                          }
                          name = "logs"
                        },
                      ]
                      workspaceId = "[if(empty(parameters('workspaceIdFromAssignment')),concat(subscription().id,'/resourcegroups/',first(split(subscription().displayName, '-')),'-','log','/providers/microsoft.operationalinsights/workspaces/',first(split(subscription().displayName, '-')),'-','log'), parameters('workspaceIdFromAssignment'))]"
                    }
                    type = "Microsoft.ContainerService/managedClusters/providers/diagnosticSettings"
                  },
                ]
                variables = {}
              }
            }
          }
          existenceCondition = {
            allOf = [
              {
                count = {
                  field = "Microsoft.Insights/diagnosticSettings/logs[*]"
                  where = {
                    allOf = [
                      {
                        equals = "True"
                        field  = "Microsoft.Insights/diagnosticSettings/logs[*].enabled"
                      },
                      {
                        field = "Microsoft.Insights/diagnosticSettings/logs[*].category"
                        in    = "[parameters('logsEnabled')]"
                      },
                    ]
                  }
                }
                equals = "[length(parameters('logsEnabled'))]"
              },
              {
                count = {
                  field = "Microsoft.Insights/diagnosticSettings/logs[*]"
                  where = {
                    allOf = [
                      {
                        equals = "True"
                        field  = "Microsoft.Insights/diagnosticSettings/logs[*].enabled"
                      },
                    ]
                  }
                }
                equals = "[length(parameters('logsEnabled'))]"
              },
              {
                field              = "Microsoft.Insights/diagnosticSettings/workspaceId"
                matchInsensitively = "[if(empty(parameters('workspaceIdFromAssignment')),concat(subscription().id,'/resourcegroups/',first(split(subscription().displayName, '-')),'-','log','/providers/microsoft.operationalinsights/workspaces/',first(split(subscription().displayName, '-')),'-','log'), parameters('workspaceIdFromAssignment'))]"
              },
            ]
          }
          roleDefinitionIds = [
            "/providers/microsoft.authorization/roleDefinitions/749f88d5-cbae-40b8-bcfc-e573ddc772fa",
            "/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293",
          ]
          type = "Microsoft.Insights/diagnosticSettings"
        }
        effect = "deployIfNotExists"
      }
    }
  )
}
