#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Add network security group and flow log

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Keep name short due to Azure weirdness. Ex: "test-2", "weekly-93".
# - MIGRATION_STRATEGY  : Relevant for ingress-nginx bootstrap. Ex: "aa", "at".

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" MIGRATION_STRATEGY=at ./create_nsg_and_flow-logs.sh

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
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.41.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI.${normal}\n"
    exit 1
fi

printf "Done.\n"

#######################################################################################
### Read inputs and configs
###

if [[ -z "${RADIX_ZONE_ENV}" ]]; then
    echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "${RADIX_ZONE_ENV}" ]]; then
        echo "ERROR: RADIX_ZONE_ENV=${RADIX_ZONE_ENV} is invalid, the file does not exist." >&2
        exit 1
    fi
    source "${RADIX_ZONE_ENV}"
fi

if [[ -z "${CLUSTER_NAME}" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

if [[ -z "${MIGRATION_STRATEGY}" ]]; then
    echo "ERROR: Please provide MIGRATION_STRATEGY" >&2
    exit 1
fi

# Read the cluster config that correnspond to selected environment in the zone config.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aks/${CLUSTER_TYPE}.env"

#######################################################################################
### Create NSG
###

NSG_ID=$(az network nsg list \
    --resource-group clusters \
    --query "[?name=='${NSG_NAME}'].id" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --output tsv \
    --only-show-errors)

if [[ ! ${NSG_ID} ]]; then
    # Create network security group
    printf "Creating azure NSG %s..." "${NSG_NAME}"
    NSG_ID=$(az network nsg create \
        --name "${NSG_NAME}" \
        --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
        --location "${AZ_RADIX_ZONE_LOCATION}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --query id \
        --output tsv \
        --only-show-errors)
    printf "Done.\n"
else
    echo "NSG exists."
fi

#######################################################################################
### Create FLOW-LOGS
###

FLOW_LOGS_STORAGEACCOUNT_EXIST=$(az storage account list \
    --resource-group "${AZ_RESOURCE_GROUP_LOGS}" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --query "[?name=='${AZ_RESOURCE_STORAGEACCOUNT_FLOW_LOGS}'].name" \
    --output tsv)

FLOW_LOGS_STORAGEACCOUNT_ID="/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_LOGS}/providers/Microsoft.Storage/storageAccounts/${AZ_RESOURCE_STORAGEACCOUNT_FLOW_LOGS}"

# Check if storage account exist
if [ ! "${FLOW_LOGS_STORAGEACCOUNT_EXIST}" ]; then
    printf "Flow logs storage account does not exists.\n"
    printf "Creating storage account %s" "${AZ_RESOURCE_STORAGEACCOUNT_FLOW_LOGS}"
    az storage account create \
        --name "${AZ_RESOURCE_STORAGEACCOUNT_FLOW_LOGS}" \
        --resource-group "${AZ_RESOURCE_GROUP_LOGS}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --location "${AZ_RADIX_ZONE_LOCATION}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --min-tls-version "${AZ_STORAGEACCOUNT_MIN_TLS_VERSION}" \
        --sku "${AZ_STORAGEACCOUNT_SKU}" \
        --kind "${AZ_STORAGEACCOUNT_KIND}" \
        --access-tier "${AZ_STORAGEACCOUNT_TIER}"
    printf "Done.\n"
else
    printf "Storage account exists.\n"
fi

if [ "$FLOW_LOGS_STORAGEACCOUNT_EXIST" ]; then
    NSG_FLOW_LOGS="$(az network nsg show \
        --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --name "${NSG_NAME}" | jq -r .flowLogs)"

    # Check if NSG has assigned Flow log
    if [[ $NSG_FLOW_LOGS != "null" ]]; then
        printf "There is an existing Flow Log on %s.\n" "${NSG_NAME}"
    else
        # Create network watcher flow log and assign to NSG
        printf "Creating azure Flow-log %s... " "${NSG_NAME}-rule"
        az network watcher flow-log create \
            --name "${NSG_NAME}-flow-log" \
            --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
            --nsg "${NSG_NAME}" \
            --location "${AZ_RADIX_ZONE_LOCATION}" \
            --storage-account "${FLOW_LOGS_STORAGEACCOUNT_ID}" \
            --subscription "${AZ_SUBSCRIPTION_ID}" \
            --retention "90" \
            --enabled true \
            --output none
        printf "Done.\n"
    fi
fi

#######################################################################################
### Create/Update VNET and associate NSG
###

VNET_EXISTS=$(az network vnet list \
    --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --query "[?name=='${VNET_NAME}'].id" \
    --output tsv \
    --only-show-errors)

if [[ ! ${VNET_EXISTS} ]]; then
    printf "Creating azure VNET %s... " "${VNET_NAME}"
    az network vnet create \
        --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
        --name "${VNET_NAME}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --address-prefix "${VNET_ADDRESS_PREFIX}" \
        --subnet-name "${SUBNET_NAME}" \
        --subnet-prefix "${VNET_SUBNET_PREFIX}" \
        --location "${AZ_RADIX_ZONE_LOCATION}" \
        --nsg "${NSG_NAME}" \
        --output none \
        --only-show-errors
    printf "Done.\n"
else
    printf "Updating azure subnet %s... " "${SUBNET_NAME}"
    az network vnet subnet update \
        --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
        --name "${SUBNET_NAME}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --vnet-name "${VNET_NAME}" \
        --network-security-group "${NSG_NAME}" \
        --output none \
        --only-show-errors
    printf "Done.\n"
fi

#######################################################################################
### Create network security group rule, update subnet.
###

if [[ "${MIGRATION_STRATEGY}" == "aa" ]]; then
    IPPRE_INGRESS_ID="/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_COMMON}/providers/Microsoft.Network/publicIPPrefixes/${AZ_IPPRE_INBOUND_NAME}"
    USED_INGRESS_IP=$(az network public-ip list \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --query "[?publicIPPrefix.id=='${IPPRE_INGRESS_ID}' && ipConfiguration.resourceGroup=='mc_${AZ_RESOURCE_GROUP_CLUSTERS}_${CLUSTER_NAME}_${AZ_RADIX_ZONE_LOCATION}'].{name:name, id:id, ipAddress:ipAddress}")
    SELECTED_INGRESS_IP="$(echo "${USED_INGRESS_IP}" | jq '.[0]')"
    SELECTED_INGRESS_IP_ID=$(echo "${SELECTED_INGRESS_IP}" | jq -r '.id')
    SELECTED_INGRESS_IP_RAW_ADDRESS="$(az network public-ip show \
        --ids "${SELECTED_INGRESS_IP_ID}" \
        --query ipAddress -o tsv)"
else
    # Create public ingress IP
    CLUSTER_PIP_NAME="pip-radix-ingress-${RADIX_ZONE}-${RADIX_ENVIRONMENT}-${CLUSTER_NAME}"
    IP_EXISTS=$(az network public-ip list \
        --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --query "[?name=='${CLUSTER_PIP_NAME}'].ipAddress" \
        --output tsv \
        --only-show-errors)

    if [[ ! ${IP_EXISTS} ]]; then
        printf "Creating Public Ingress IP..."
        SELECTED_INGRESS_IP_RAW_ADDRESS=$(az network public-ip create \
            --name "${CLUSTER_PIP_NAME}" \
            --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
            --location "${AZ_RADIX_ZONE_LOCATION}" \
            --subscription "${AZ_SUBSCRIPTION_ID}" \
            --allocation-method Static \
            --sku Standard \
            --tier Regional \
            --query "publicIp.ipAddress" \
            --output tsv \
            --only-show-errors) || {
            echo "ERROR: Could not create Public IP. Quitting..." >&2
            exit 1
        }
        printf "Done.\n"
    else
        SELECTED_INGRESS_IP_RAW_ADDRESS="${IP_EXISTS}"
    fi
fi

printf "Creating azure NSG rule %s-rule... " "${NSG_NAME}"
az network nsg rule create \
    --nsg-name "${NSG_NAME}" \
    --name "${NSG_NAME}-rule" \
    --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --destination-address-prefixes "${SELECTED_INGRESS_IP_RAW_ADDRESS}" \
    --destination-port-ranges 80 443 \
    --access "Allow" \
    --direction "Inbound" \
    --priority 100 \
    --protocol Tcp \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --output none \
    --only-show-errors
printf "Done.\n"

printf "Updating subnet %s to associate NSG... " "${SUBNET_NAME}"
az network vnet subnet update \
    --vnet-name "${VNET_NAME}" \
    --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
    --name "${SUBNET_NAME}" \
    --subscription "${AZ_SUBSCRIPTION_ID}" \
    --network-security-group "${NSG_NAME}" \
    --output none \
    --only-show-errors || { echo "ERROR: Could not update subnet." >&2; }
printf "Done.\n"
