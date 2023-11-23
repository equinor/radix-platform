output "GITHUB_DEV_CLUSTER_FED" {
  value = {
    "environments" = {
      "environment" = var.GH_ENVIRONMENT,
      "secrets"     = {
        "AZURE_CLIENT_ID"       = data.azurerm_client_config.CLIENT_CONFIG.client_id,
        "AZURE_SUBSCRIPTION_ID" = data.azurerm_subscription.AZ_SUBSCRIPTION.id,
        "AZURE_TENANT_ID"       = data.azurerm_client_config.CLIENT_CONFIG.tenant_id,
      }
    }
  }
}
