#!/bin/bash

# PURPOSE
#
# The purpose of the shell script is to set up a new cluster 
# within a subscription on an existing resource group
#
# To run this script from terminal: 
# AZ_INFRASTRUCTURE_ENVIRONMENT=dev CLUSTER_NAME=weekly-10 ./bootstrap.sh
#
# INPUTS:
#   AZ_INFRASTRUCTURE_ENVIRONMENT   (Mandatory - "prod" or "dev")
#   CLUSTER_NAME                    (Mandatory. Example: "prod43")
#   USER_PROMPT                     (Optional. Defaulted if omitted. ex: false,true. Will skip any user input, so that script can run to the end with no interaction)
#
# CREDENTIALS:
# See "Set credentials" for key/value pairs.
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
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
hash jq 2> /dev/null  || { echo -e "\nError: jq not found in PATH. Exiting... " >&2;  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nError: kubectl not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"


#######################################################################################
### CONFIGS
###

### Validate mandatory input

if [[ -z "$AZ_INFRASTRUCTURE_ENVIRONMENT" ]]; then
    echo "Please provide AZ_INFRASTRUCTURE_ENVIRONMENT. Value must be one of: \"prod\", \"dev\", \"test\"."
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME."
    exit 1
fi

if [[ -z "$CREDENTIALS_FILE" ]]; then
    credentials_source="keyvault"
else
    credentials_source="$CREDENTIALS_FILE"
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

### Get cluster config that correnspond to selected environment
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/${AZ_INFRASTRUCTURE_ENVIRONMENT}.env"


### Get radix base env vars
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../${AZ_INFRASTRUCTURE_ENVIRONMENT}.env"


#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION" >/dev/null
printf "Done.\n"


#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Bootstrap will use the following configuration:"
echo -e ""
echo -e "   INFRASTRUCTURE_ENVIRONMENT : $AZ_INFRASTRUCTURE_ENVIRONMENT"
echo -e ""
echo -e "   CLUSTER_NAME               : $CLUSTER_NAME"
echo -e "   KUBERNETES_VERSION         : $KUBERNETES_VERSION"
echo -e "   NODE_COUNT                 : $NODE_COUNT"
echo -e "   NODE_DISK_SIZE             : $NODE_DISK_SIZE"
echo -e "   NODE_VM_SIZE               : $NODE_VM_SIZE"
echo -e ""
echo -e "   VNET_NAME                  : $VNET_NAME"
echo -e "   VNET_ADDRESS_PREFIX        : $VNET_ADDRESS_PREFIX"
echo -e "   VNET_SUBNET_PREFIX         : $VNET_SUBNET_PREFIX"
echo -e "   NETWORK_PLUGIN             : $NETWORK_PLUGIN"
echo -e "   NETWORK_POLICY             : $NETWORK_POLICY"
echo -e "   SUBNET_NAME                : $SUBNET_NAME"
echo -e "   VNET_DOCKER_BRIDGE_ADDRESS : $VNET_DOCKER_BRIDGE_ADDRESS"
echo -e "   VNET_DNS_SERVICE_IP        : $VNET_DNS_SERVICE_IP"
echo -e "   VNET_SERVICE_CIDR          : $VNET_SERVICE_CIDR"
echo -e ""
echo -e "   USE CREDENTIALS FROM       : $credentials_source"
echo -e ""
echo -e "   AZ_SUBSCRIPTION            : $AZ_SUBSCRIPTION"
echo -e "   AZ_USER                    : $(az account show --query user.name -o tsv)"
echo -e ""
echo -e "   USER_PROMPT                : $USER_PROMPT"
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
### Network
###

echo "Bootstrap advanced network for aks instance \"${CLUSTER_NAME}\"... "

printf "   Creating azure VNET ${VNET_NAME}... " 
az network vnet create -g "$AZ_RESOURCE_GROUP_CLUSTERS" \
    -n $VNET_NAME \
    --address-prefix $VNET_ADDRESS_PREFIX \
    --subnet-name $SUBNET_NAME \
    --subnet-prefix $VNET_SUBNET_PREFIX \
    2>&1 >/dev/null
printf "Done.\n"

printf "   Granting access to VNET ${VNET_NAME} for Service Principal ${CLUSTER_SYSTEM_USER_ID}... "
SUBNET_ID=$(az network vnet subnet list --resource-group $AZ_RESOURCE_GROUP_CLUSTERS --vnet-name $VNET_NAME --query [].id --output tsv)
VNET_ID="$(az network vnet show --resource-group $AZ_RESOURCE_GROUP_CLUSTERS -n $VNET_NAME --query "id" --output tsv)"
printf "Done.\n"

# Delete any existing roles
printf "   Deleting existing roles... "
az role assignment delete --assignee "${CLUSTER_SYSTEM_USER_ID}" --scope "${VNET_ID}" 2>&1 >/dev/null
printf "Done.\n"

# Configure new roles
printf "   Creating new roles... "
az role assignment create --assignee "${CLUSTER_SYSTEM_USER_ID}" \
   --role "Network Contributor" \
   --scope "${VNET_ID}" \
   2>&1 >/dev/null
printf "Done.\n"

echo "Bootstrap of advanced network done."


#######################################################################################
### Create cluster
###

echo "Creating aks instance \"${CLUSTER_NAME}\"... " 

az aks create --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME" \
    --no-ssh-key \
    --kubernetes-version "$KUBERNETES_VERSION" \
    --service-principal "$CLUSTER_SYSTEM_USER_ID" \
    --client-secret "$CLUSTER_SYSTEM_USER_PASSWORD" \
    --node-count "$NODE_COUNT" \
    --node-osdisk-size "$NODE_DISK_SIZE" \
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
    --aad-tenant-id "$AAD_TENANT_ID" \
    --network-policy "$NETWORK_POLICY" \
    2>&1 >/dev/null

echo "Done."


#######################################################################################
### Update local kube config
###

printf "Updating local kube config with admin access to cluster \"$CLUSTER_NAME\"... "
az aks get-credentials --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS"  --name "$CLUSTER_NAME" \
    --overwrite-existing \
    --admin \
    2>&1 >/dev/null
printf "Done.\n"


#######################################################################################
### END
###

if [ "$AZ_INFRASTRUCTURE_ENVIRONMENT" == "prod" ]; then

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