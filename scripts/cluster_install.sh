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
# VAULT_NAME=aa CREDENTIALS_SECRET_NAME=bb RESOURCE_GROUP=cc CLUSTER_NAME=dd KUBERNETES_VERSION=ee NODE_COUNT=ff NODE_VM_SIZE=gg  ./cluster_install.sh
#
# Input environment variables:
#   VAULT_NAME
#   CREDENTIALS_SECRET_NAME (defaulted if omitted)
#   RESOURCE_GROUP
#   CLUSTER_NAME
#   KUBERNETES_VERSION (defaulted if omitted)
#   NODE_COUNT (defaulted if omitted)
#   NODE_VM_SIZE (defaulted if omitted)
#
# Secret environment variables (downloaded from keyvault):
#   AAD_SERVER_APP_ID
#   AAD_SERVER_APP_SECRET
#   AAD_CLIENT_APP_ID
#   AAD_TENANT_ID
#   SERVICE_PRINCIPAL
#   CLIENT_SECRET

if [[ -z "$CREDENTIALS_SECRET_NAME" ]]; then
    CREDENTIALS_SECRET_NAME="credentials-new"
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

# Step 1: Download credentials from vault as sh script
az keyvault secret show --vault-name "$VAULT_NAME" --name "$CREDENTIALS_SECRET_NAME" | jq -r .value > "./credentials"

# Step 2: Execute shell script to set environment variables
source ./credentials

# Step 3: Create cluster
echo "Creating azure kubernetes service ${CLUSTER_NAME}..." 
command="az aks create --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" \
    --no-ssh-key \
    --kubernetes-version "$KUBERNETES_VERSION" \
    --aad-server-app-id "$AAD_SERVER_APP_ID" \
    --aad-server-app-secret "$AAD_SERVER_APP_SECRET" \
    --aad-client-app-id "$AAD_CLIENT_APP_ID" \
    --aad-tenant-id "$AAD_TENANT_ID" \
    --service-principal "$SERVICE_PRINCIPAL" \
    --client-secret "$CLIENT_SECRET" \
    --node-count "$NODE_COUNT" \
    --node-vm-size "$NODE_VM_SIZE""

echo "Running command:"
echo
#echo $command

# $command

echo
echo -e "Azure kubernetes service ${CLUSTER_NAME} created"

# Step 4: Remove credentials file
rm -f ./credentials