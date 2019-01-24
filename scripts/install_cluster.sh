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
#   VNET_NAME                   (Optional. Defaulted if omitted)
#   VNET_ADDRESS_PREFIX         (Optional. Defaulted if omitted)
#   VNET_SUBNET_PREFIX          (Optional. Defaulted if omitted)
#   NETWORK_PLUGIN              (Optional. Defaulted if omitted)
#   SUBNET_NAME                 (Optional. Defaulted if omitted)
#   VNET_DOCKER_BRIDGE_ADDRESS  (Optional. Defaulted if omitted)
#   VNET_DNS_SERVICE_IP         (Optional. Defaulted if omitted)
#   VNET_SERVICE_CIDR           (Optional. Defaulted if omitted)
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

if [[ -z "$POD_PER_NODE" ]]; then
    POD_PER_NODE="110"
fi

if [[ -z "$VNET_NAME" ]]; then
    VNET_NAME="vnet-$CLUSTER_NAME"
fi

if [[ -z "$VNET_ADDRESS_PREFIX" ]]; then
    VNET_ADDRESS_PREFIX="192.168.0.0/16"
fi

if [[ -z "$VNET_SUBNET_PREFIX" ]]; then
    VNET_SUBNET_PREFIX="192.168.0.0/18"
fi

if [[ -z "$NETWORK_PLUGIN" ]]; then
    NETWORK_PLUGIN="azure"
fi

if [[ -z "$SUBNET_NAME" ]]; then
    SUBNET_NAME="subnet-$CLUSTER_NAME"
fi

if [[ -z "$VNET_DOCKER_BRIDGE_ADDRESS" ]]; then
    VNET_DOCKER_BRIDGE_ADDRESS="172.17.0.1/16"
fi

if [[ -z "$VNET_DNS_SERVICE_IP" ]]; then
    VNET_DNS_SERVICE_IP="10.2.0.10"
fi

if [[ -z "$VNET_SERVICE_CIDR" ]]; then
    VNET_SERVICE_CIDR="10.2.0.0/18"
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
echo -e "INFRASTRUCTURE_ENVIRONMENT : $INFRASTRUCTURE_ENVIRONMENT"
echo -e "CLUSTER_NAME               : $CLUSTER_NAME"
echo -e "VAULT_NAME                 : $VAULT_NAME"
echo -e "RESOURCE_GROUP             : $RESOURCE_GROUP"
echo -e "KUBERNETES_VERSION         : $KUBERNETES_VERSION"
echo -e "NODE_COUNT                 : $NODE_COUNT"
echo -e "NODE_VM_SIZE               : $NODE_VM_SIZE"
echo -e "VNET_NAME                  : $VNET_NAME"
echo -e "VNET_ADDRESS_PREFIX        : $VNET_ADDRESS_PREFIX"
echo -e "VNET_SUBNET_PREFIX         : $VNET_SUBNET_PREFIX"
echo -e "NETWORK_PLUGIN             : $NETWORK_PLUGIN"
echo -e "SUBNET_NAME                : $SUBNET_NAME"
echo -e "VNET_DOCKER_BRIDGE_ADDRESS : $VNET_DOCKER_BRIDGE_ADDRESS"
echo -e "VNET_DNS_SERVICE_IP        : $VNET_DNS_SERVICE_IP"
echo -e "VNET_SERVICE_CIDR          : $VNET_SERVICE_CIDR"
echo -e ""
echo -e "USE CREDENTIALS FROM      : $credentials_source"
echo -e ""

# Step 3: Create VNET
echo "Creating azure VNET ${VNET_NAME}..." 

az network vnet create -g "$RESOURCE_GROUP" \
    -n $VNET_NAME \
    --address-prefix $VNET_ADDRESS_PREFIX \
    --subnet-name $SUBNET_NAME \
    --subnet-prefix $VNET_SUBNET_PREFIX

echo "Granting access to VNET ${VNET_NAME} for service principles ${CLUSTER_SYSTEM_USER_ID}..." 

SUBNET_ID=$(az network vnet subnet list --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --query [].id --output tsv)
VNET_ID="$(az network vnet show --resource-group $RESOURCE_GROUP -n $VNET_NAME --query "id" --output tsv)"

# Delete any existing roles
az role assignment delete --assignee "${CLUSTER_SYSTEM_USER_ID}" --scope "${VNET_ID}"

# Configure new roles
az role assignment create --assignee "${CLUSTER_SYSTEM_USER_ID}" --role "Network Contributor" --scope "${VNET_ID}"

# Step 4: Create cluster
echo "Creating azure kubernetes service ${CLUSTER_NAME}..." 

az aks create --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
    --no-ssh-key \
    --kubernetes-version "$KUBERNETES_VERSION" \
    --service-principal "$CLUSTER_SYSTEM_USER_ID" \
    --client-secret "$CLUSTER_SYSTEM_USER_PASSWORD" \
    --node-count "$NODE_COUNT" \
    --node-vm-size "$NODE_VM_SIZE" \
    --max-pods "$POD_PER_NODE" \
    --network-plugin "$NETWORK_PLUGIN" \
    --vnet-subnet-id "$SUBNET_ID" \
    --docker-bridge-address "$VNET_DOCKER_BRIDGE_ADDRESS" \
    --dns-service-ip "$VNET_DNS_SERVICE_IP" \
    --service-cidr "$VNET_SERVICE_CIDR" \
    --aad-server-app-id "$AAD_SERVER_APP_ID" \
    --aad-server-app-secret "$AAD_SERVER_APP_SECRET" \
    --aad-client-app-id "$AAD_CLIENT_APP_ID" \
    --aad-tenant-id "$AAD_TENANT_ID"

az aks create    

echo - ""
echo -e "Azure kubernetes service \"${CLUSTER_NAME}\" created."

# Step 5: Enter the newly created cluster
az aks get-credentials --overwrite-existing --admin --resource-group "$RESOURCE_GROUP"  --name "$CLUSTER_NAME"
