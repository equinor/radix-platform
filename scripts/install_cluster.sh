#!/bin/bash

# PRECONDITIONS
#
# It is assumed that az, kubectl, and jq are installed
#
# PURPOSE
#
# The purpose of the shell script is to set up a new cluster 
# within a subscription on an existing resource group
#
# To run this script from terminal: 
# INFRASTRUCTURE_ENVIRONMENT=bb CLUSTER_NAME=dd ./install_cluster.sh
#
# Example:
# INFRASTRUCTURE_ENVIRONMENT=dev CLUSTER_NAME=cluster42 ./install_cluster.sh
#
# INPUTS:
#   INFRASTRUCTURE_ENVIRONMENT  (Mandatory - "prod", "dev")
#   CLUSTER_NAME                (Mandatory. Example: "prod43")
#   VAULT_NAME                  (Optional. Example: "radix-vault-prod")
#   RESOURCE_GROUP              (Optional. Example: "clusters")
#   KUBERNETES_VERSION          (Optional. Defaulted if omitted)
#   NODE_COUNT                  (Optional. Defaulted if omitted)
#   NODE_VM_SIZE                (Optional. Defaulted if omitted)
#   CREDENTIALS_FILE            (Optional. Default to read values from keyvault)
#
# CREDENTIALS:
# See "Step 1: Set credentials" for key/value pairs.
#
# Default (no file provided as input)
#   The script will read credentials from keyvault each required system user and slack token.
#
# Custom (user provide CREDENTIALS_FILE)
# The credentials file must contain a list of key/value pairs which when sourced will be read as a variable list by the script.
# Example:
# CLUSTER_SYSTEM_USER_ID=(guid)
# CLUSTER_SYSTEM_USER_PASSWORD=(string)
# AAD_SERVER_APP_ID=(guid)

# Validate mandatory input
if [[ -z "$INFRASTRUCTURE_ENVIRONMENT" ]]; then
    echo "Please provide INFRASTRUCTURE_ENVIRONMENT. Value must be one of: \"prod\", \"dev\"."
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME."
    exit 1
fi

# Set default values for optional input
if [[ -z "$VAULT_NAME" ]]; then
    VAULT_NAME="radix-vault-$INFRASTRUCTURE_ENVIRONMENT"
fi

if [[ -z "$RESOURCE_GROUP" ]]; then
    RESOURCE_GROUP="clusters"
fi

if [[ -z "$KUBERNETES_VERSION" ]]; then
    KUBERNETES_VERSION="1.11.5"
fi

if [[ -z "$NODE_COUNT" ]]; then
    NODE_COUNT="3"
fi

if [[ -z "$NODE_VM_SIZE" ]]; then
    NODE_VM_SIZE="Standard_DS4_v2"
fi

# Step 1: Set credentials
echo "Reading credentials..."
if [[ -z "$CREDENTIALS_FILE" ]]; then
    # No file found, default to read credentials from keyvault
    # Key/value pairs (these are the one you must provide if you want to use a custom credentials file)   
    CLUSTER_SYSTEM_USER_ID="$(az keyvault secret show --vault-name $VAULT_NAME --name radix-cluster-$INFRASTRUCTURE_ENVIRONMENT | jq -r .value | jq -r .id)"
    CLUSTER_SYSTEM_USER_PASSWORD="$(az keyvault secret show --vault-name $VAULT_NAME --name radix-cluster-$INFRASTRUCTURE_ENVIRONMENT | jq -r .value | jq -r .password)"
    AAD_SERVER_APP_ID="$(az keyvault secret show --vault-name $VAULT_NAME --name radix-cluster-aad-server-$INFRASTRUCTURE_ENVIRONMENT | jq -r .value | jq -r .id)"
    AAD_SERVER_APP_SECRET="$(az keyvault secret show --vault-name $VAULT_NAME --name radix-cluster-aad-server-$INFRASTRUCTURE_ENVIRONMENT | jq -r .value | jq -r .password)"
    AAD_TENANT_ID="$(az keyvault secret show --vault-name $VAULT_NAME --name radix-cluster-aad-server-$INFRASTRUCTURE_ENVIRONMENT | jq -r .value | jq -r .tenantId)"
    AAD_CLIENT_APP_ID="$(az keyvault secret show --vault-name $VAULT_NAME --name radix-cluster-aad-client-$INFRASTRUCTURE_ENVIRONMENT | jq -r .value | jq -r .id)"
    SLACK_TOKEN="$(az keyvault secret show --vault-name $VAULT_NAME --name slack-token | jq -r .value)"
    # Helper var for log output
    credentials_source="keyvault"
else
    # Credentials are provided from input.
    # Source the file to make the key/value pairs readable as script vars    
    source ./"$CREDENTIALS_FILE"
    # Helper var for log output
    credentials_source="$CREDENTIALS_FILE"
fi

# Step 2: Show what we got before starting on the The Great Work
echo -e ""
echo -e "Start deploy of cluster using the following settings:"
echo -e ""
echo -e "INFRASTRUCTURE_ENVIRONMENT: $INFRASTRUCTURE_ENVIRONMENT"
echo -e "CLUSTER_NAME              : $CLUSTER_NAME"
echo -e "VAULT_NAME                : $VAULT_NAME"
echo -e "RESOURCE_GROUP            : $RESOURCE_GROUP"
echo -e "KUBERNETES_VERSION        : $KUBERNETES_VERSION"
echo -e "NODE_COUNT                : $NODE_COUNT"
echo -e "NODE_VM_SIZE              : $NODE_VM_SIZE"
echo -e ""
echo -e "USE CREDENTIALS FROM      : $credentials_source"
echo -e ""

# Step 3: Create cluster
echo "Creating azure kubernetes service ${CLUSTER_NAME}..." 

az aks create --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
    --no-ssh-key \
    --kubernetes-version "$KUBERNETES_VERSION" \
    --service-principal "$CLUSTER_SYSTEM_USER_ID" \
    --client-secret "$CLUSTER_SYSTEM_USER_PASSWORD" \
    --node-count "$NODE_COUNT" \
    --node-vm-size "$NODE_VM_SIZE" \
    --aad-server-app-id "$AAD_SERVER_APP_ID" \
    --aad-server-app-secret "$AAD_SERVER_APP_SECRET" \
    --aad-client-app-id "$AAD_CLIENT_APP_ID" \
    --aad-tenant-id "$AAD_TENANT_ID"

echo - ""
echo -e "Azure kubernetes service \"${CLUSTER_NAME}\" created."

# Step 4: Enter the newly created cluster
az aks get-credentials --overwrite-existing --admin --resource-group "$RESOURCE_GROUP"  --name "$CLUSTER_NAME"
