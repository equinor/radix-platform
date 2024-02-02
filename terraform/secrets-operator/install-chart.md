
[https://external-secrets.io/v0.9.11/introduction/getting-started/](https://external-secrets.io/v0.9.11/introduction/getting-started/)

- helm repo add external-secrets https://charts.external-secrets.io
- helm install external-secrets ...
- Lag ny Azure managed identity: radix-id-external-secrets-operator-dev
    - K8S OIDC issuer URL: `az aks show -g clusters-development -n weekly-04 --query oidcIssuerProfile.issuerUrl -otsv`






# MISC

## Federated credentials example:

```terraform
resource "azurerm_federated_identity_credential" "github-push-master" {
  for_each = toset(var.github-credentials)

  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  name                = "gh-radix-vulnerability-scanner-workflow-${each.key}"
  parent_id           = azurerm_user_assigned_identity.github.id
  resource_group_name = azurerm_resource_group.rg.name
  subject             = "repo:equinor/radix-vulnerability-scanner:ref:refs/heads/${each.key}"
}

```
