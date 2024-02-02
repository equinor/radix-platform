resource "azurerm_user_assigned_identity" "userassignedidentity" {
  name                = "radix-id-external-secrets-operator-dev"
  location            = "northeurope"
  resource_group_name = "common-dev"
}

resource "azurerm_federated_identity_credential" "github-push-master" {
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://northeurope.oic.prod-aks.azure.com/3aa4a235-b6e2-48d5-9195-7fcf05b459b0/68e8873d-cb09-42a6-b5a3-196d189353ab/"
  name                = "operator-weekly-04"
  parent_id           = azurerm_user_assigned_identity.userassignedidentity.id
  resource_group_name = azurerm_user_assigned_identity.userassignedidentity.resource_group_name
  subject             = "system:serviceaccount:external-secrets:workload-identity-sa"
}


data "azurerm_key_vault" "keyvault" {
  name                = "radix-vault-dev"
  resource_group_name = "common"
}

resource "azurerm_key_vault_access_policy" "keyvault-policy" {
  key_vault_id = data.azurerm_key_vault.keyvault.id
  object_id    = azurerm_user_assigned_identity.userassignedidentity.principal_id
  tenant_id    = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"

  secret_permissions = ["Get", "List"]
}

output "mi-client-id" {
  value = azurerm_user_assigned_identity.userassignedidentity.client_id
}
