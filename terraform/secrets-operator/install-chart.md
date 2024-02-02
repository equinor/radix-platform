
[https://external-secrets.io/v0.9.11/introduction/getting-started/](https://external-secrets.io/v0.9.11/introduction/getting-started/)

- helm repo add external-secrets https://charts.external-secrets.io
- helm install external-secrets ...
- Lag ny Azure managed identity: radix-id-external-secrets-operator-dev
    - K8S OIDC issuer URL: `az aks show -g clusters-development -n weekly-04 --query oidcIssuerProfile.issuerUrl -otsv`






# MISC

## Federated credentials example:

```terraform
resource "azurerm_federated_identity_credential" "github-push-master" {
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://northeurope.oic.prod-aks.azure.com/3aa4a235-b6e2-48d5-9195-7fcf05b459b0/68e8873d-cb09-42a6-b5a3-196d189353ab/"
  name                = "operator-wi"
  parent_id           = azurerm_user_assigned_identity.github.id
  resource_group_name = azurerm_resource_group.rg.name
  subject             = "system:serviceaccount:external-secrets:workload-identity-sa"
}

```
