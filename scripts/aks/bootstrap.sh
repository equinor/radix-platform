#!/usr/bin/env bash

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

# When creating a test cluster
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=beastmode-11 MIGRATION_STRATEGY=at ./bootstrap.sh

# When creating a cluster that will become an active cluster (creating a cluster in advance)
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=beastmode-11 MIGRATION_STRATEGY=aa ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap aks instance... "

#######################################################################################
### Check for prerequisites binaries
###

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting... " >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.41.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI.${normal}\n"
    exit 1
fi

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}

printf "Done.\n"

#######################################################################################
### Read inputs and configs
###

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "ERROR: RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

if [[ -z "$MIGRATION_STRATEGY" ]]; then
    echo "ERROR: Please provide MIGRATION_STRATEGY" >&2
    exit 1
fi

# Read the cluster config that correnspond to selected environment in the zone config.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/${CLUSTER_TYPE}.env"

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

# Optional inputs

if [[ -z "$CREDENTIALS_FILE" ]]; then
    CREDENTIALS_FILE=""
else
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        echo "ERROR: CREDENTIALS_FILE=\"${CREDENTIALS_FILE}\" is not a valid file path." >&2
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

    local HUB_PEERED_VNET_JSON="$(az network vnet peering list \
        --resource-group "$AZ_RESOURCE_GROUP_VNET_HUB" \
        --vnet-name "$AZ_VNET_HUB_NAME")"
    local HUB_PEERED_VNET_EXISTING="$(echo "$HUB_PEERED_VNET_JSON" | jq --arg HUB_PEERING_NAME "${HUB_PEERING_NAME}" '.[] | select(.name==$HUB_PEERING_NAME)' | jq -r '.remoteAddressSpace.addressPrefixes[0]')"
    if [[ -n "$HUB_PEERED_VNET_EXISTING" ]]; then
        # vnet peering exist from before - use same IP
        local withoutCIDR=${HUB_PEERED_VNET_EXISTING%"/16"}
        echo "$withoutCIDR"
        return
    fi

    local HUB_PEERED_VNET_IP="$(echo "$HUB_PEERED_VNET_JSON" | jq '.[].remoteAddressSpace.addressPrefixes')"

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

if [ "$OMNIA_ZONE" = "standalone" ]; then
    echo "Getting unused VNET address space... "
    AKS_VNET_ADDRESS_PREFIX="$(getAddressSpaceForVNET)"
    VNET_ADDRESS_PREFIX="$AKS_VNET_ADDRESS_PREFIX/16"
    VNET_SUBNET_PREFIX="$AKS_VNET_ADDRESS_PREFIX/18"
else
    echo "Unknown parameter"
fi

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
echo -e "   -  AZ_RESOURCE_GROUP_COMMON         : $AZ_RESOURCE_GROUP_COMMON"
echo -e "   -  AZ_RESOURCE_GROUP_CLUSTERS       : $AZ_RESOURCE_GROUP_CLUSTERS"
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
echo -e "   -  NSG_NAME                         : $NSG_NAME"
echo -e "   -  NETWORK_PLUGIN                   : $NETWORK_PLUGIN"
echo -e "   -  NETWORK_POLICY                   : $NETWORK_POLICY"
echo -e "   -  SUBNET_NAME                      : $SUBNET_NAME"
echo -e "   -  VNET_DOCKER_BRIDGE_ADDRESS       : $VNET_DOCKER_BRIDGE_ADDRESS"
echo -e "   -  VNET_DNS_SERVICE_IP              : $VNET_DNS_SERVICE_IP"
echo -e "   -  VNET_SERVICE_CIDR                : $VNET_SERVICE_CIDR"
echo -e "   -  HUB_VNET_RESOURCE_GROUP          : $AZ_RESOURCE_GROUP_VNET_HUB"
echo -e "   -  HUB_VNET_NAME                    : $AZ_VNET_HUB_NAME"
echo -e "   -  OUTBOUND_IP_COUNT                : $OUTBOUND_IP_COUNT"
echo -e "   -  K8S_API_IP_WHITELIST             : $K8S_API_IP_WHITELIST"
echo -e ""
echo -e "   - USE CREDENTIALS FROM              : $(if [[ -z $CREDENTIALS_FILE ]]; then printf "%s" "$AZ_RESOURCE_KEYVAULT"; else printf "%s" "$CREDENTIALS_FILE"; fi)"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -r -p "Is this correct? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            echo ""
            echo "Quitting."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    echo ""
fi

#######################################################################################
### Set credentials
###

printf "Reading credentials... "
if [[ -z "$CREDENTIALS_FILE" ]]; then
    # No file found, default to read credentials from keyvault
    # Key/value pairs (these are the one you must provide if you want to use a custom credentials file)
    # AAD_SERVER_APP_ID="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $AZ_RESOURCE_AAD_SERVER | jq -r .value | jq -r .id)"
    # AAD_SERVER_APP_SECRET="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $AZ_RESOURCE_AAD_SERVER | jq -r .value | jq -r .password)"
    # AAD_TENANT_ID="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $AZ_RESOURCE_AAD_SERVER | jq -r .value | jq -r .tenantId)"
    # AAD_CLIENT_APP_ID="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $AZ_RESOURCE_AAD_CLIENT | jq -r .value | jq -r .id)"
    ID_AKS="$(az identity show \
        --name "$MI_AKS" \
        --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
        --query 'id' \
        --output tsv 2>/dev/null)"
    ID_AKSKUBELET="$(az identity show \
        --name "$MI_AKSKUBELET" \
        --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
        --query 'id' \
        --output tsv 2>/dev/null)"
    ACR_ID="$(az acr show \
        --name "${AZ_RESOURCE_CONTAINER_REGISTRY}" \
        --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
        --query "id" \
        --output tsv)"
else
    # Credentials are provided from input.
    # Source the file to make the key/value pairs readable as script vars
    source ./"$CREDENTIALS_FILE"
fi
printf "Done.\n"

#######################################################################################
### Verify credentials
###
if [ -z "$ID_AKS" ]; then
    echo "ERROR: Managed identity \"$MI_AKS\" does not exist. Exiting..." >&2
    exit 1
fi
if [ -z "$ID_AKSKUBELET" ]; then
    echo "ERROR: Managed identity \"$ID_AKSKUBELET\" does not exist. Exiting..." >&2
    exit 1
fi
if [ -z "$ACR_ID" ]; then
    echo "ERROR: Azure Container Registry \"$ACR_ID\" does not exist. Exiting..." >&2
    exit 1
fi
#######################################################################################
### Specify static public outbound IPs
###

# MIGRATION_STRATEGY outbound PIP assignment
# if migrating active to active cluster (eg. dev to dev)
if [ "$MIGRATION_STRATEGY" = "aa" ]; then
    # Path to Public IP Prefix which contains the public outbound IPs
    IPPRE_EGRESS_ID="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/$AZ_RESOURCE_GROUP_COMMON/providers/Microsoft.Network/publicIPPrefixes/$AZ_IPPRE_OUTBOUND_NAME"
    IPPRE_INGRESS_ID="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/$AZ_RESOURCE_GROUP_COMMON/providers/Microsoft.Network/publicIPPrefixes/$AZ_IPPRE_INBOUND_NAME"

    # list of AVAILABLE public EGRESS ips assigned to the Radix Zone
    echo "Getting list of available public egress ips in $RADIX_ZONE..."
    AVAILABLE_EGRESS_IPS="$(az network public-ip list \
        --query "[?publicIPPrefix.id=='${IPPRE_EGRESS_ID}' && ipConfiguration.resourceGroup==null].{name:name, id:id, ipAddress:ipAddress}")"

    # Select range of egress ips based on OUTBOUND_IP_COUNT
    SELECTED_EGRESS_IPS="$(echo "$AVAILABLE_EGRESS_IPS" | jq '.[0:'$OUTBOUND_IP_COUNT']')"

    # list of AVAILABLE public INGRESS ips assigned to the Radix Zone
    printf "Getting list of available public ingress ips in %s..." "$RADIX_ZONE"
    AVAILABLE_INGRESS_IPS="$(az network public-ip list \
        --query "[?publicIPPrefix.id=='${IPPRE_INGRESS_ID}' && ipConfiguration.resourceGroup==null].{name:name, id:id, ipAddress:ipAddress}")"

    # Select first available ingress ip
    SELECTED_INGRESS_IPS="$(echo "$AVAILABLE_INGRESS_IPS" | jq '.[0]')"

    if [[ "$AVAILABLE_EGRESS_IPS" == "[]" || "$AVAILABLE_INGRESS_IPS" == "[]" ]]; then
        echo "ERROR: Query returned no ips. Please check the variable AZ_IPPRE_OUTBOUND_NAME in RADIX_ZONE_ENV and that the IP-prefix exists. Exiting..." >&2
        printf "Tip: You might need to do a teardown of an early clusters first.\n"
        exit 1
    elif [[ -z $AVAILABLE_EGRESS_IPS ]]; then
        echo "ERROR: Found no available ips to assign to the destination cluster. Exiting..." >&2
        exit 1
    else
        echo ""
        echo "-----------------------------------------------------------"
        echo ""
        echo "The following public egress IP(s) are currently available:"
        echo "$AVAILABLE_EGRESS_IPS" | jq -r '.[].name'
        echo ""
        echo "The following public egress IP(s) will be assigned to the cluster:"
        echo "$SELECTED_EGRESS_IPS" | jq -r '.[].name'
        echo "-----------------------------------------------------------"
        echo ""
        echo "The following public ingress IP(s) are currently available:"
        echo "$AVAILABLE_INGRESS_IPS" | jq -r '.[].name'
        echo ""
        echo "The following public ingress IP(s) will be assigned to the cluster:"
        echo "$SELECTED_INGRESS_IPS" | jq -r '.name'
        echo ""
        echo "-----------------------------------------------------------"
    fi

    echo ""
    USER_PROMPT="true"
    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -r -p "Is this correct? (Y/n) " yn
            case $yn in
            [Yy]*)
                echo ""
                echo "Sounds good, continuing."
                break
                ;;
            [Nn]*)
                echo ""
                echo "Quitting."
                exit 0
                ;;
            *) echo "Please answer yes or no." ;;
            esac
        done
    fi
    echo ""

    # Create the comma separated string of egress ip resource ids to pass in as --load-balancer-outbound-ips for aks
    while read -r line; do
        EGRESS_IP_ID_LIST+="${line},"
    done <<<"$(echo ${SELECTED_EGRESS_IPS} | jq -r '.[].id')"
    EGRESS_IP_ID_LIST=${EGRESS_IP_ID_LIST%,} # Remove trailing comma
fi

#######################################################################################
### Network
###

echo "Bootstrap advanced network for aks instance \"${CLUSTER_NAME}\"... "

#######################################################################################
### Create NSG and update subnet
###

NSG_ID="$(az network nsg list \
    --resource-group clusters \
    --query "[?name=='${NSG_NAME}'].id" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --output tsv \
    --only-show-errors)"

if [[ ! ${NSG_ID} ]]; then
    # Create network security group
    printf "    Creating azure NSG %s..." "${NSG_NAME}"
    NSG_ID=$(az network nsg create \
        --name "$NSG_NAME" \
        --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
        --location "$AZ_RADIX_ZONE_LOCATION" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --query id \
        --output tsv \
        --only-show-errors)
    printf " Done.\n"
else
    echo "    NSG exists."
fi

# NSG Flow Logs
FLOW_LOGS_STORAGEACCOUNT_EXIST=$(az storage account list \
    --resource-group "$AZ_RESOURCE_GROUP_LOGS" \
    --query "[?name=='$AZ_RESOURCE_STORAGEACCOUNT_FLOW_LOGS'].name" \
    --output tsv)
FLOW_LOGS_STORAGEACCOUNT_ID="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/$AZ_RESOURCE_GROUP_LOGS/providers/Microsoft.Storage/storageAccounts/$AZ_RESOURCE_STORAGEACCOUNT_FLOW_LOGS"

if [ ! "$FLOW_LOGS_STORAGEACCOUNT_EXIST" ]; then
    printf "Flow logs storage account does not exists.\n"

    printf "    Creating storage account %s" "$AZ_RESOURCE_STORAGEACCOUNT_FLOW_LOGS"
    az storage account create \
        --name "$AZ_RESOURCE_STORAGEACCOUNT_FLOW_LOGS" \
        --resource-group "$AZ_RESOURCE_GROUP_LOGS" \
        --location "$AZ_RADIX_ZONE_LOCATION" \
        --subscription "$AZ_SUBSCRIPTION_ID"
        --min-tls-version "${AZ_STORAGEACCOUNT_MIN_TLS_VERSION}" \
        --sku "${AZ_STORAGEACCOUNT_SKU}" \
        --kind "${AZ_STORAGEACCOUNT_KIND}" \
        --access-tier "${AZ_STORAGEACCOUNT_TIER}"
    printf "Done.\n"
else
    printf "    Storage account exists.\n"
fi

if [ "$FLOW_LOGS_STORAGEACCOUNT_EXIST" ]; then
    NSG_FLOW_LOGS="$(az network nsg show --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$NSG_NAME" | jq -r .flowLogs)"

    # Check if NSG has assigned Flow log
    if [[ $NSG_FLOW_LOGS != "null" ]]; then
        printf "    There is an existing Flow Log on %s\n" "$NSG_NAME"
    else
        # Create network watcher flow log and assign to NSG
        printf "    Creating azure Flow-log %s...\n" "${NSG_NAME}-rule"
        az network watcher flow-log create \
            --name "${NSG_NAME}-flow-log" \
            --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
            --nsg "$NSG_NAME" \
            --location "$AZ_RADIX_ZONE_LOCATION" \
            --storage-account "$FLOW_LOGS_STORAGEACCOUNT_ID" \
            --subscription "$AZ_SUBSCRIPTION_ID" \
            --retention "90" \
            --enabled true \
            --output none
        printf "    Done.\n"
    fi
fi

# Create VNET and associate NSG
VNET_EXISTS="$(az network vnet list \
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
    --query "[?name=='${VNET_NAME}'].id" \
    --output tsv \
    --only-show-errors)"

if [[ ! ${VNET_EXISTS} ]]; then
    printf "    Creating azure VNET %s... " "${VNET_NAME}"
    az network vnet create \
        --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
        --name "$VNET_NAME" \
        --address-prefix "$VNET_ADDRESS_PREFIX" \
        --subnet-name "$SUBNET_NAME" \
        --subnet-prefix "$VNET_SUBNET_PREFIX" \
        --location "$AZ_RADIX_ZONE_LOCATION" \
        --nsg "$NSG_NAME" \
        --output none \
        --only-show-errors
    printf "Done.\n"
fi

SUBNET_ID="$(az network vnet subnet list \
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
    --vnet-name "$VNET_NAME" \
    --query [].id \
    --output tsv)"

VNET_ID="$(az network vnet show \
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
    --name "$VNET_NAME" \
    --query "id" \
    --output tsv)"

# peering VNET to hub-vnet
HUB_VNET_RESOURCE_ID="$(az network vnet show \
    --resource-group "$AZ_RESOURCE_GROUP_VNET_HUB" \
    --name "$AZ_VNET_HUB_NAME" \
    --query "id" \
    --output tsv)"

echo "Peering vnet $VNET_NAME to hub-vnet $HUB_VNET_RESOURCE_ID... "

az network vnet peering create \
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
    --name "$VNET_PEERING_NAME" \
    --vnet-name "$VNET_NAME" \
    --remote-vnet "$HUB_VNET_RESOURCE_ID" \
    --allow-vnet-access 2>&1

az network vnet peering create \
    --resource-group "$AZ_RESOURCE_GROUP_VNET_HUB" \
    --name "$HUB_PEERING_NAME" \
    --vnet-name "$AZ_VNET_HUB_NAME" \
    --remote-vnet "$VNET_ID" \
    --allow-vnet-access 2>&1

function linkPrivateDnsZoneToVNET() {
    local dns_zone=${1}
    local PRIVATE_DNS_ZONE_EXIST="$(az network private-dns zone show \
        --resource-group "$AZ_RESOURCE_GROUP_VNET_HUB" \
        --name "$dns_zone" \
        --query "id" \
        --output tsv 2>&1)"
    local DNS_ZONE_LINK_EXIST="$(az network private-dns link vnet show \
        --resource-group "$AZ_RESOURCE_GROUP_VNET_HUB" \
        --name "$VNET_DNS_LINK" \
        --zone-name "$dns_zone" \
        --query "type" \
        --output tsv 2>&1)"

    if [[ $PRIVATE_DNS_ZONE_EXIST == *"ARMResourceNotFoundFix"* ]]; then
        echo "ERROR: Private DNS Zone ${dns_zone} not found." >&2
    elif [[ $DNS_ZONE_LINK_EXIST != "Microsoft.Network/privateDnsZones/virtualNetworkLinks" ]]; then
        echo "Linking private DNS Zone:  ${dns_zone} to K8S VNET ${VNET_ID}"
        # throws error if run twice
        az network private-dns link vnet create \
            --resource-group "$AZ_RESOURCE_GROUP_VNET_HUB" \
            --name "$VNET_DNS_LINK" \
            --zone-name "$dns_zone" \
            --virtual-network "$VNET_ID" \
            --registration-enabled False 2>&1
    fi
}

# linking private dns zones to vnet
echo "Linking private DNS Zones to vnet $VNET_NAME... "
for dns_zone in "${AZ_PRIVATE_DNS_ZONES[@]}"; do
    linkPrivateDnsZoneToVNET "$dns_zone" &
done
wait

echo "Bootstrap of advanced network done."

#######################################################################################
### Create cluster
###

echo "Creating aks instance \"${CLUSTER_NAME}\"... "

###############################################################################
### Add Usermode pool - System - Tainted
###

AKS_BASE_OPTIONS=(
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS"
    --name "$CLUSTER_NAME"
    --no-ssh-key
    --kubernetes-version "$KUBERNETES_VERSION"
    --node-osdisk-size "$NODE_DISK_SIZE"
    --node-vm-size "$NODE_VM_SIZE"
    --max-pods "$POD_PER_NODE"
    --network-plugin "$NETWORK_PLUGIN"
    --network-policy "$NETWORK_POLICY"
    --docker-bridge-address "$VNET_DOCKER_BRIDGE_ADDRESS"
    --dns-service-ip "$VNET_DNS_SERVICE_IP"
    --service-cidr "$VNET_SERVICE_CIDR"
    --location "$AZ_RADIX_ZONE_LOCATION"
    --enable-managed-identity
    --enable-aad
    --aad-admin-group-object-ids "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d"
    --assign-identity "$ID_AKS"
    --assign-kubelet-identity "$ID_AKSKUBELET"
    --attach-acr "$ACR_ID"
    --api-server-authorized-ip-ranges "$K8S_API_IP_WHITELIST"
    --vnet-subnet-id "$SUBNET_ID"
    --disable-local-accounts
    --enable-addons azure-keyvault-secrets-provider
    --nodepool-name systempool
    --enable-secret-rotation
    --enable-oidc-issuer
    --enable-cluster-autoscaler
    --node-count "$SYSTEM_MIN_COUNT"
    --min-count "$SYSTEM_MIN_COUNT"
    --max-count "$SYSTEM_MAX_COUNT"
)

if [ "$MIGRATION_STRATEGY" = "aa" ]; then
    MIGRATION_STRATEGY_OPTIONS=(
        --load-balancer-outbound-ips "$EGRESS_IP_ID_LIST"
        --load-balancer-outbound-ports "4000"
    )
fi

if [ "$CLUSTER_TYPE" = "production" ]; then
    AKS_CLUSTER_OPTIONS=(
        --uptime-sla
    )
elif [[ "$CLUSTER_TYPE" = "playground" ]]; then
    AKS_CLUSTER_OPTIONS=(
        --uptime-sla
    )
elif [[ "$CLUSTER_TYPE" = "development" ]]; then
    AKS_CLUSTER_OPTIONS=()
elif [[ "$CLUSTER_TYPE" = "classicdev" ]]; then
    AKS_CLUSTER_OPTIONS=(
        --vnet-subnet-id "/subscriptions/c44d61d9-1f68-4236-aa19-2103b69766d5/resourceGroups/S045-NE-network/providers/Microsoft.Network/virtualNetworks/S045-NE-vnet"
    )
elif [[ "$CLUSTER_TYPE" = "classicprod" ]]; then
    AKS_CLUSTER_OPTIONS=(
        --vnet-subnet-id "/subscriptions/7790e999-c11c-4f0b-bfdf-bc2fd5c38e91/resourceGroups/S340-NE-network/providers/Microsoft.Network/virtualNetworks/S340-NE-vnet"
    )
else
    echo "ERROR: Unknown parameter" >&2
fi

az aks create "${AKS_BASE_OPTIONS[@]}" "${AKS_CLUSTER_OPTIONS[@]}" "${MIGRATION_STRATEGY_OPTIONS[@]}"

#######################################################################################
### Assign Contributor on scope of nodepool RG for AKS managed identity
###

node_pool_resource_group=MC_${AZ_RESOURCE_GROUP_CLUSTERS}_${CLUSTER_NAME}_${AZ_RADIX_ZONE_LOCATION}
managed_identity_id=$(az identity show \
    --id /subscriptions/${AZ_SUBSCRIPTION_ID}/resourcegroups/${AZ_RESOURCE_GROUP_COMMON}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${MI_AKS} \
    --query principalId \
    -o tsv)

printf "Assigning Contributor role to ${MI_AKS} on scope of resource group ${node_pool_resource_group}..."
az role assignment create \
    --role Contributor \
    --assignee "$managed_identity_id" \
    --scope $(az group show --name ${node_pool_resource_group} --query id -o tsv)
printf "Done.\n"

printf "Assigning Contributor role to ${MI_AKS} on scope of resource group ${AZ_RESOURCE_GROUP_COMMON}... \n"
az role assignment create \
    --role Contributor \
    --assignee "$managed_identity_id" \
    --scope $(az group show --name ${AZ_RESOURCE_GROUP_COMMON} --query id -o tsv)
printf "Done.\n"

#######################################################################################
### Tag cluster with migrationStrategy
###

printf "Tagging cluster ${CLUSTER_NAME} with tag migrationStrategy=${MIGRATION_STRATEGY}...\n"
az resource tag \
    --ids /subscriptions/${AZ_SUBSCRIPTION_ID}/resourcegroups/${AZ_RESOURCE_GROUP_CLUSTERS}/providers/Microsoft.ContainerService/managedClusters/${CLUSTER_NAME} \
    --tags migrationStrategy="${MIGRATION_STRATEGY}"  &>/dev/null
printf "Done.\n"

#######################################################################################
### Get api server whitelist
###

(USER_PROMPT=false CLUSTER_NAME="${CLUSTER_NAME}" source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/update_api_server_whitelist.sh")

#######################################################################################
### Lock cluster and network resources
###

if [ "$RADIX_ENVIRONMENT" = "prod" ]; then
    az lock create \
        --lock-type CanNotDelete \
        --name "${CLUSTER_NAME}"-lock \
        --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
        --resource-type Microsoft.ContainerService/managedClusters \
        --resource "$CLUSTER_NAME" &>/dev/null

    az lock create --lock-type CanNotDelete \
        --name "${VNET_NAME}"-lock \
        --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
        --resource-type Microsoft.Network/virtualNetworks \
        --resource "$VNET_NAME" &>/dev/null
fi

#######################################################################################
### Update local kube config
###

printf "Updating local kube config with access to cluster \"%s\"... " "$CLUSTER_NAME"
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" >/dev/null

[[ "$(kubectl config current-context)" != "$CLUSTER_NAME" ]] && exit 1

printf "Done.\n"

#######################################################################################
### Taint the 'systempool'
###
echo "Taint the 'systempool'"
az aks nodepool update --cluster-name "$CLUSTER_NAME" --name systempool --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --node-taints CriticalAddonsOnly=true:NoSchedule --labels nodepool-type=system nodepoolos=linux app=system-apps  >/dev/null
printf "Done.\n"
#######################################################################################
### Add untainted User nodepool
###

AKS_USER_OPTIONS=(
    --cluster-name "$CLUSTER_NAME"
    --nodepool-name userpool
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS"
    --enable-cluster-autoscaler
    --kubernetes-version "$KUBERNETES_VERSION"
    --max-count "$MAX_COUNT"
    --max-pods "$POD_PER_NODE"
    --min-count "$MIN_COUNT"
    --mode User
    --node-count "$NODE_COUNT"
    --node-osdisk-size "$NODE_DISK_SIZE"
    --node-vm-size "$NODE_VM_SIZE"
    --vnet-subnet-id "$SUBNET_ID"
)
echo "Create user nodepool"
az aks nodepool add "${AKS_USER_OPTIONS[@]}"

#######################################################################################
### Add GPU node pools
###

printf "Adding GPU node pools to the cluster... "

az aks nodepool add \
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
    --cluster-name "$CLUSTER_NAME" \
    --name nc6sv3 \
    --enable-cluster-autoscaler \
    --node-count 0 \
    --min-count 0 \
    --max-count 1 \
    --max-pods 110 \
    --node-vm-size Standard_NC6s_v3 \
    --labels sku=gpu gpu=nvidia-v100 gpu-count=1 radix-node-gpu=nvidia-v100 radix-node-gpu-count=1 \
    --node-taints sku=gpu:NoSchedule \
    --node-taints gpu=nvidia-v100:NoSchedule \
    --node-taints gpu-count=1:NoSchedule \
    --node-taints radix-node-gpu=nvidia-v100:NoSchedule \
    --node-taints radix-node-gpu-count=1:NoSchedule \
    --no-wait \
    --output none \
    --only-show-errors

az aks nodepool add \
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
    --cluster-name "$CLUSTER_NAME" \
    --name nc12sv3 \
    --enable-cluster-autoscaler \
    --node-count 0 \
    --min-count 0 \
    --max-count 1 \
    --max-pods 110 \
    --node-vm-size Standard_NC12s_v3 \
    --labels sku=gpu gpu=nvidia-v100 gpu-count=2 radix-node-gpu=nvidia-v100 radix-node-gpu-count=2 \
    --node-taints sku=gpu:NoSchedule \
    --node-taints gpu=nvidia-v100:NoSchedule \
    --node-taints gpu-count=2:NoSchedule \
    --node-taints radix-node-gpu=nvidia-v100:NoSchedule \
    --node-taints radix-node-gpu-count=2:NoSchedule \
    --no-wait \
    --output none \
    --only-show-errors

az aks nodepool add \
    --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
    --cluster-name "$CLUSTER_NAME" \
    --name nc24sv3 \
    --enable-cluster-autoscaler \
    --node-count 0 \
    --min-count 0 \
    --max-count 1 \
    --max-pods 110 \
    --node-vm-size Standard_NC24s_v3 \
    --labels sku=gpu gpu=nvidia-v100 gpu-count=4 radix-node-gpu=nvidia-v100 radix-node-gpu-count=4 \
    --node-taints sku=gpu:NoSchedule \
    --node-taints gpu=nvidia-v100:NoSchedule \
    --node-taints gpu-count=4:NoSchedule \
    --node-taints radix-node-gpu=nvidia-v100:NoSchedule \
    --node-taints radix-node-gpu-count=4:NoSchedule \
    --no-wait \
    --output none \
    --only-show-errors

printf "Done."

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
