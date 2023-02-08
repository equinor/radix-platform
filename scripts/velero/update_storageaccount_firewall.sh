#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Whitelist cluster vnet and subnet for velero backup storage account

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

#######################################################################################
### HOW TO USE
### 

# add
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" ACTION="add" ./update_storageaccount_firewall.sh

# delete
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" ACTION="delete" ./update_storageaccount_firewall.sh


#######################################################################################
### Check for prerequisites binaries
###

echo ""
echo "Start whitelist cluster..."

echo ""
printf "Check for necessary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}

printf "All is good."
echo ""

#######################################################################################
### Read inputs and configs
###

# Required inputs

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

if [ "${ACTION}" != "add" ] && [ "${ACTION}" != "delete" ]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Read the cluster config that correnspond to selected environment in the zone config.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../aks/${CLUSTER_TYPE}.env"

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### START
###

subnetId=$(az network vnet subnet show \
    --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
    --vnet-name "${VNET_NAME}" \
    --name "${SUBNET_NAME}" \
    --query id \
    --output tsv \
    --only-show-errors)

function add-subnet-to-firewall() {
    printf "\nAdding Microsoft.Storage to subnet...\n "
    az network vnet subnet update \
        --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" \
        --vnet-name "${VNET_NAME}" \
        --name "${SUBNET_NAME}" \
        --service-endpoints "Microsoft.Storage" \
        --output tsv \
        --only-show-errors
    printf "Done.\n"

    printf "\nAdding subnet to storage account...\n "
    az storage account network-rule add \
        --resource-group "${AZ_VELERO_RESOURCE_GROUP}" \
        --account-name "${AZ_VELERO_STORAGE_ACCOUNT_ID}" \
        --subnet "${subnetId}" \
        --output tsv \
        --only-show-errors
    printf "Done.\n"
}

function delete-subnet-from-firewall() {
    printf "\nRemoving subnet from storage account...\n "
    az storage account network-rule remove \
        --account-name "${AZ_VELERO_STORAGE_ACCOUNT_ID}" \
        --resource-group "${AZ_VELERO_RESOURCE_GROUP}" \
        --subnet "${subnetId}" \
        --output tsv \
        --only-show-errors
    printf "Done.\n"
}

if [[ "${ACTION}" == "add" ]]; then
    add-subnet-to-firewall
elif [[ "${ACTION}" == "delete" ]]; then
    delete-subnet-from-firewall
fi
