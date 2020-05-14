#!/bin/bash

#######################################################################################
### PURPOSE
###

# Bootstrap aks instance in a radix zone

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Keep name short due to Azure weirdness. Ex: "test-2", "weekly-93".

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.
# - CREDENTIALS_FILE    : Path to credentials in the form of shell vars. See "Set credentials" for required key/value pairs.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=beastmode-11 ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap aks instance... "

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nError: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nError: jq not found in PATH. Exiting... " >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nError: kubectl not found in PATH. Exiting... " >&2
    exit 1
}
printf "Done.\n"

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Read the cluster config that correnspond to selected environment in the zone config.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../${RADIX_ENVIRONMENT}.env"

# Optional inputs

if [[ -z "$CREDENTIALS_FILE" ]]; then
    CREDENTIALS_FILE=""
else
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "CREDENTIALS_FILE=\"${CREDENTIALS_FILE}\" is not a valid file path." >&2
        exit 1
    fi
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Bootstrap AKS will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e "   -  KUBERNETES_VERSION               : $KUBERNETES_VERSION"
echo -e "   -  NODE_COUNT                       : $NODE_COUNT"
echo -e "   -  NODE_DISK_SIZE                   : $NODE_DISK_SIZE"
echo -e "   -  NODE_VM_SIZE                     : $NODE_VM_SIZE"
echo -e ""
echo -e "   -  NETWORK_PLUGIN                   : $NETWORK_PLUGIN"
echo -e "   -  NETWORK_POLICY                   : $NETWORK_POLICY"
echo -e "   -  VNET_DOCKER_BRIDGE_ADDRESS       : $VNET_DOCKER_BRIDGE_ADDRESS"
echo -e "   -  VNET_DNS_SERVICE_IP              : $VNET_DNS_SERVICE_IP"
echo -e "   -  VNET_SERVICE_CIDR                : $VNET_SERVICE_CIDR"
echo -e ""
echo -e "   - USE CREDENTIALS FROM              : $(if [[ -z $CREDENTIALS_FILE ]]; then printf $AZ_RESOURCE_KEYVAULT; else printf $CREDENTIALS_FILE; fi)"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    read -p "Is this correct? (Y/n) " -n 1 -r
    if [[ "$REPLY" =~ (N|n) ]]; then
        echo ""
        echo "Quitting."
        exit 0
    fi
    echo ""
fi

echo ""

#######################################################################################
### Set credentials
###

printf "Reading credentials... "
if [[ -z "$CREDENTIALS_FILE" ]]; then
    # No file found, default to read credentials from keyvault
    # Key/value pairs (these are the one you must provide if you want to use a custom credentials file)
    CLUSTER_SYSTEM_USER_ID="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $AZ_SYSTEM_USER_CLUSTER | jq -r .value | jq -r .id)"
    CLUSTER_SYSTEM_USER_PASSWORD="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $AZ_SYSTEM_USER_CLUSTER | jq -r .value | jq -r .password)"
    AAD_SERVER_APP_ID="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $AZ_RESOURCE_AAD_SERVER | jq -r .value | jq -r .id)"
    AAD_SERVER_APP_SECRET="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $AZ_RESOURCE_AAD_SERVER | jq -r .value | jq -r .password)"
    AAD_TENANT_ID="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $AZ_RESOURCE_AAD_SERVER | jq -r .value | jq -r .tenantId)"
    AAD_CLIENT_APP_ID="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $AZ_RESOURCE_AAD_CLIENT | jq -r .value | jq -r .id)"
else
    # Credentials are provided from input.
    # Source the file to make the key/value pairs readable as script vars
    source ./"$CREDENTIALS_FILE"
fi
printf "Done.\n"

#######################################################################################
### Create cluster
###

echo "Creating aks instance \"${CLUSTER_NAME}\"... "

SUBNET_ID=$(az network vnet subnet list -g $AZ_RESOURCE_GROUP_NETWORK --vnet-name $AZ_VNET_SPOKE_NAME --query [].id --output tsv)
az aks create --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME" \
    --no-ssh-key \
    --enable-private-cluster \
    --kubernetes-version "$KUBERNETES_VERSION" \
    --service-principal "$CLUSTER_SYSTEM_USER_ID" \
    --client-secret "$CLUSTER_SYSTEM_USER_PASSWORD" \
    --node-count "$NODE_COUNT" \
    --node-osdisk-size "$NODE_DISK_SIZE" \
    --node-vm-size "$NODE_VM_SIZE" \
    --max-pods "$POD_PER_NODE" \
    --network-plugin "$NETWORK_PLUGIN" \
    --network-policy "$NETWORK_POLICY" \
    --vnet-subnet-id "$SUBNET_ID" \
    --docker-bridge-address "$VNET_DOCKER_BRIDGE_ADDRESS" \
    --dns-service-ip "$VNET_DNS_SERVICE_IP" \
    --service-cidr "$VNET_SERVICE_CIDR" \
    --aad-server-app-id "$AAD_SERVER_APP_ID" \
    --aad-server-app-secret "$AAD_SERVER_APP_SECRET" \
    --aad-client-app-id "$AAD_CLIENT_APP_ID" \
    --aad-tenant-id "$AAD_TENANT_ID" \
    --location "$AZ_RADIX_ZONE_LOCATION"

echo "Done."

#######################################################################################
### Update local kube config
###

printf "Updating local kube config with admin access to cluster \"$CLUSTER_NAME\"... "
az aks get-credentials --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME" \
    --overwrite-existing \
    --admin \
    2>&1 >/dev/null
printf "Done.\n"

#######################################################################################
### END
###

if [ "$RADIX_ENVIRONMENT" == "prod" ]; then

    echo ""
    echo "###########################################################"
    echo ""
    echo "FOR PRODUCTION ONLY: ENABLE AKS DIAGNOSTIC LOGS"
    echo ""
    echo "You need to manually enable AKS Diagnostic logs. See https://docs.microsoft.com/en-us/azure/aks/view-master-logs ."
    echo ""
    echo "Complete the steps in the section 'Enable diagnostics logs'. "
    echo "PS: It has been enabled on our subscriptions so no need to do that step."
    echo ""
    echo "###########################################################"

fi

echo ""
echo "Boostrap of \"${CLUSTER_NAME}\" done!"
