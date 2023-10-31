# DR:
# Comment out backend "azurerm" {} to run local
scripts/radix-zone/base-infrastructure/bootstrap.sh
    create_common_resources
    create_outbound_public_ip_prefix
    create_inbound_public_ip_prefix
    create_acr
terraform/infrastructure/s941/dev/resourcegroups/main.tf # local
terraform/infrastructure/s941/dev/keyvaults/main.tf # local
terraform/infrastructure/s941/dev/storageaccounts/main.tf # local
terraform/oidc/rbac/main.tf # local
terraform/infrastructure/s941/dev/policy/main.tf
terraform/infrastructure/s941/dev/networkmanager/main.tf
scripts/service-principals-and-aad-apps/refresh_web_console_app_credentials.sh





# TODO
find SP_GITHUB_ACTION_CLUSTER_CLIENT_ID with name instead of hardcoding ID

# Testing
#ar-radix-hub-dev

AZ_RESOURCE_GROUP_VNET_HUB="cluster-vnet-hub-dev"
ROLE="Contributor"
ROLE_SCOPE="$(az group show --name "${AZ_RESOURCE_GROUP_VNET_HUB}" --query "id" --output tsv)"
USER_ID="$(az ad sp list --display-name "ar-radix-hub-dev" --query [].appId --output tsv)"

az role assignment create \
    --assignee "${USER_ID}" \
    --role "${ROLE}" \
    --scope "${ROLE_SCOPE}"

-------------------------------------------

create_role_assignment_for_identity \
    "${MI_AKS}" \
    "Managed Identity Operator" \
    "$(az identity show --name id-radix-aks-development-northeurope --resource-group common --subscription "939950ec-da7e-4349-8b8d-77d9c278af04" --query id 2>/dev/null)"


az role assignment create \
    --role "Managed Identity Operator" \
    --assignee "35b6ea8d-4dc2-4a43-8a7a-db21425c6a95" \
    --scope "/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04/resourcegroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-radix-aks-development-northeurope" \
    --subscription "939950ec-da7e-4349-8b8d-77d9c278af04" \
    --output none \
    --only-show-errors



role_name: Managed Identity Operator
scope: "/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04/resourcegroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-radix-aks-development-northeurope"
AZ_SUBSCRIPTION_ID: 939950ec-da7e-4349-8b8d-77d9c278af04
id_name: id-radix-aks-development-northeurope
role_name: Managed Identity Operator
scope: "/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04/resourcegroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-radix-aks-development-northeurope"
id: 35b6ea8d-4dc2-4a43-8a7a-db21425c6a95
testRA:



/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04/resourceGroups/clusters/providers/Microsoft.Network/networkManagers/s612-ANVM/networkGroups/dev/providers/Microsoft.Authorization/policyAssignments/kubernetes-vnets-in-dev

/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04/providers/Microsoft.Authorization/policyAssignments/Kubernetes-vnets-in-dev

/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04/providers/Microsoft.Authorization/policyDefinitions/Kubernetes-vnets-in-dev


az network vnet peering list --resource-group clusters --vnet-name vnet-weekly-dr-test --query "[].id" --output tsv