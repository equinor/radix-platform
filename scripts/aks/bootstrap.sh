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
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/${RADIX_ENVIRONMENT}.env"

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

if [[ -z "$HUB_PEERING_NAME" ]]; then
    HUB_PEERING_NAME=hub-to-${CLUSTER_NAME}
fi

if [[ -z "$VNET_DNS_LINK" ]]; then
    VNET_DNS_LINK=$CLUSTER_NAME-link
fi


#######################################################################################
### support functions
###

function getAddressSpaceForVNET() {
    
    local HUB_PEERED_VNET_JSON="$(az network vnet peering list -g $AZ_RESOURCE_GROUP_VNET_HUB --vnet-name $AZ_VNET_HUB_NAME)"
    local HUB_PEERED_VNET_EXISTING="$(echo $HUB_PEERED_VNET_JSON | jq --arg HUB_PEERING_NAME "${HUB_PEERING_NAME}" '.[] | select(.name==$HUB_PEERING_NAME)' | jq -r '.remoteAddressSpace.addressPrefixes[0]')"
    if [[ ! -z "$HUB_PEERED_VNET_EXISTING" ]]; then
        # vnet peering exist from before - use same IP
        local withoutCIDR=${HUB_PEERED_VNET_EXISTING%"/16"}
        echo "$withoutCIDR"
        return
    fi

    local HUB_PEERED_VNET_IP="$(echo $HUB_PEERED_VNET_JSON | jq '.[].remoteAddressSpace.addressPrefixes')"

    for i in {3..255}; do
        # 10.0.0.0/16 is reserved by HUB, 10.2.0.0/16 is reserved for AKS owned services (e.g. internal k8s DNS service).  
        local PROPOSED_VNET_ADDRESS="10.$i.0.0"
        if [[ $HUB_PEERED_VNET_IP != *$PROPOSED_VNET_ADDRESS* ]]; then
            echo "$PROPOSED_VNET_ADDRESS"
            return
        fi
    done
}


#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Get unused VNET address prefix
###

echo "Getting unused VNET address space... "
AKS_VNET_ADDRESS_PREFIX="$(getAddressSpaceForVNET)"
VNET_ADDRESS_PREFIX="$AKS_VNET_ADDRESS_PREFIX/16"
VNET_SUBNET_PREFIX="$AKS_VNET_ADDRESS_PREFIX/18"

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
echo -e "   -  VNET_NAME                        : $VNET_NAME"
echo -e "   -  VNET_ADDRESS_PREFIX              : $VNET_ADDRESS_PREFIX"
echo -e "   -  VNET_SUBNET_PREFIX               : $VNET_SUBNET_PREFIX"
echo -e "   -  NETWORK_PLUGIN                   : $NETWORK_PLUGIN"
echo -e "   -  NETWORK_POLICY                   : $NETWORK_POLICY"
echo -e "   -  SUBNET_NAME                      : $SUBNET_NAME"
echo -e "   -  VNET_DOCKER_BRIDGE_ADDRESS       : $VNET_DOCKER_BRIDGE_ADDRESS"
echo -e "   -  VNET_DNS_SERVICE_IP              : $VNET_DNS_SERVICE_IP"
echo -e "   -  VNET_SERVICE_CIDR                : $VNET_SERVICE_CIDR"
echo -e "   -  HUB_VNET_RESOURCE_GROUP          : $AZ_RESOURCE_GROUP_VNET_HUB"
echo -e "   -  HUB_VNET_NAME                    : $AZ_VNET_HUB_NAME"
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
### Network
###

echo "Bootstrap advanced network for aks instance \"${CLUSTER_NAME}\"... "

printf "   Creating azure VNET ${VNET_NAME}... "
az network vnet create -g "$AZ_RESOURCE_GROUP_CLUSTERS" \
    -n "$VNET_NAME" \
    --address-prefix "$VNET_ADDRESS_PREFIX" \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefix "$VNET_SUBNET_PREFIX" \
    --location "$AZ_RADIX_ZONE_LOCATION" \
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

# peering VNET to hub-vnet
HUB_VNET_RESOURCE_ID="$(az network vnet show --resource-group $AZ_RESOURCE_GROUP_VNET_HUB -n $AZ_VNET_HUB_NAME --query "id" --output tsv)"
echo "Peering vnet $VNET_NAME to hub-vnet $HUB_VNET_RESOURCE_ID... "
az network vnet peering create -g $AZ_RESOURCE_GROUP_CLUSTERS -n $VNET_PEERING_NAME --vnet-name $VNET_NAME --remote-vnet $HUB_VNET_RESOURCE_ID --allow-vnet-access 2>&1
az network vnet peering create -g $AZ_RESOURCE_GROUP_VNET_HUB -n $HUB_PEERING_NAME --vnet-name $AZ_VNET_HUB_NAME --remote-vnet $VNET_ID --allow-vnet-access 2>&1

function linkPrivateDnsZoneToVNET() {
    local dns_zone=${1}
    local DNS_ZONE_LINK_EXIST="$(az network private-dns link vnet show -g $AZ_RESOURCE_GROUP_VNET_HUB -n $VNET_DNS_LINK -z $dns_zone --query "type" --output tsv 2>&1)"
    if [[ $DNS_ZONE_LINK_EXIST != "Microsoft.Network/privateDnsZones/virtualNetworkLinks" ]]; then
        echo "Linking private DNS Zone:  ${dns_zone} to K8S VNET ${VNET_ID}"
        # throws error if run twice
        az network private-dns link vnet create -g $AZ_RESOURCE_GROUP_VNET_HUB -n $VNET_DNS_LINK -z $dns_zone -v $VNET_ID -e False 2>&1
    fi
}

# linking private dns zones to vnet
echo "Linking private DNS Zones to vnet $VNET_NAME... "
for dns_zone in "${AZ_PRIVATE_DNS_ZONES[@]}"; do
    linkPrivateDnsZoneToVNET $dns_zone &
done
wait

echo "Bootstrap of advanced network done."

#######################################################################################
### Create cluster
###

echo "Creating aks instance \"${CLUSTER_NAME}\"... "

### It might be required to add "--node-count 10 \" below "--max-count "$MAX_COUNT" \" if deploying certain VM sizes
az aks create --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME" \
    --no-ssh-key \
    --kubernetes-version "$KUBERNETES_VERSION" \
    --service-principal "$CLUSTER_SYSTEM_USER_ID" \
    --client-secret "$CLUSTER_SYSTEM_USER_PASSWORD" \
    --enable-cluster-autoscaler \
    --min-count "$MIN_COUNT" \
    --max-count "$MAX_COUNT" \
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
    --location "$AZ_RADIX_ZONE_LOCATION" \
    2>&1 >/dev/null

echo "Done."

#######################################################################################
### Update local kube config
###

printf "Updating local kube config with admin access to cluster \"$CLUSTER_NAME\"... "
az aks get-credentials --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME" \
    --overwrite-existing \
    --admin \
    2>&1 >/dev/null

[[ "$(kubectl config current-context)" != "$CLUSTER_NAME-admin" ]] && exit 1

printf "Done.\n"


#######################################################################################
### Add GPU node pools
###
echo "Adding GPU node pools to the cluster... "

az aks nodepool add \
    --resource-group clusters \
    --cluster-name "$CLUSTER_NAME" \
    --name nc6sv3 \
    --node-count 0 \
    --max-pods 110 \
    --node-vm-size Standard_NC6s_v3 \
    --labels sku=gpu gpu=nvidia-v100 gpu-count=1 radix-node-gpu=nvidia-v100 radix-node-gpu-count=1 \
    --node-taints sku=gpu:NoSchedule \
    --node-taints gpu=nvidia-v100:NoSchedule \
    --node-taints gpu-count=1:NoSchedule \
    --node-taints radix-node-gpu=nvidia-v100:NoSchedule \
    --node-taints radix-node-gpu-count=1:NoSchedule \
    --no-wait \
    2>&1 >/dev/null

az aks nodepool add \
    --resource-group clusters \
    --cluster-name "$CLUSTER_NAME" \
    --name nc12sv3 \
    --node-count 0 \
    --max-pods 110 \
    --node-vm-size Standard_NC12s_v3 \
    --labels sku=gpu gpu=nvidia-v100 gpu-count=2 radix-node-gpu=nvidia-v100 radix-node-gpu-count=2 \
    --node-taints sku=gpu:NoSchedule \
    --node-taints gpu=nvidia-v100:NoSchedule \
    --node-taints gpu-count=2:NoSchedule \
    --node-taints radix-node-gpu=nvidia-v100:NoSchedule \
    --node-taints radix-node-gpu-count=2:NoSchedule \
    --no-wait \
    2>&1 >/dev/null

az aks nodepool add \
    --resource-group clusters \
    --cluster-name "$CLUSTER_NAME" \
    --name nc24sv3 \
    --node-count 0 \
    --max-pods 110 \
    --node-vm-size Standard_NC24s_v3 \
    --labels sku=gpu gpu=nvidia-v100 gpu-count=4 radix-node-gpu=nvidia-v100 radix-node-gpu-count=4 \
    --node-taints sku=gpu:NoSchedule \
    --node-taints gpu=nvidia-v100:NoSchedule \
    --node-taints gpu-count=4:NoSchedule \
    --node-taints radix-node-gpu=nvidia-v100:NoSchedule \
    --node-taints radix-node-gpu-count=4:NoSchedule \
    --no-wait \
    2>&1 >/dev/null

echo "Done."

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
echo "Bootstrap of \"${CLUSTER_NAME}\" done!"
