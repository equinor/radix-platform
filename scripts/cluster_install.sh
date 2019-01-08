# PRECONDITIONS
#
# It is assumed that kubectl, jq... are installed
#
# PURPOSE
#
# The purpose of the shell script is to set up a cluster 
# within a subscription
#
# To run this script from terminal:
# RESOURCE_GROUP=xx CLUSTER_NAME=yy ...  ./cluster_install.sh
#
# Input environment variables:
#   RESOURCE_GROUP
#   CLUSTER_NAME
#   KUBERNETES_VERSION
#   NODE_COUNT
#   NODE_VM_SIZE

if [ -n "$KUBERNETES_VERSION" ]; then
    KUBERNETES_VERSION = "1.11.5"
fi

if [ -n "$NODE_COUNT" ]; then
    NODE_COUNT = "3"
fi

if [ -n "$NODE_VM_SIZE" ]; then
    NODE_VM_SIZE = "Standard_DS4_v2"
fi

# Step 1: Download credentials_new from vault as sh script

# Step 2: Execute shell script to set environment variables

# Step 3: Create cluster
echo "Creating azure kubernetes service ${CLUSTER_NAME}..." 
command = "az aks create --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
    --no-ssh-key \
    --kubernetes-version "$KUBERNETES_VERSION" \
    --aad-server-app-id "$AAD_SERVER_APP_ID" \
    --aad-server-app-secret "$(jq -r '.adServerAppSecret' $__credentials_path)" \
    --aad-client-app-id "$(jq -r '.adClientAppId' $__credentials_path)" \
    --aad-tenant-id "$(jq -r '.tenantId' $__credentials_path)" \
    --service-principal "$(jq -r '.servicePrincipalId' $__credentials_path)" \
    --client-secret "$(jq -r '.servicePrincipalSecret' $__credentials_path)" \
    --node-count "$NODE_COUNT" \
    --node-vm-size "$NODE_VM_SIZE""

echo "Running command:"
echo
echo $command

$command

echo
echo -e "Azure kubernetes service ${CLUSTER_NAME} created"

