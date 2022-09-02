#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# delete records belonging to specific cluster

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# To run this script from terminal:
# RADIX_ZONE_ENV=aa.env ./delete_dns_entries_for_cluster.sh

# Example: Delete from dev
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./delete_dns_entries_for_cluster.sh

# Example: Delete from playground
# RADIX_ZONE_ENV=../radix-zone/radix_zone_playground.env ./delete_dns_entries_for_cluster.sh

#######################################################################################
### Validate mandatory input
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

if [[ -z "$AZ_SUBSCRIPTION_ID" ]]; then
    echo "ERROR: AZ_SUBSCRIPTION_ID is not defined. Please check the .env file." >&2
    exit 1
fi

if [[ -z "$AZ_RESOURCE_DNS" ]]; then
    echo "ERROR: AZ_RESOURCE_DNS is not defined. Please check the .env file." >&2
    exit 1
fi

if [[ -z "$AZ_RESOURCE_GROUP_COMMON" ]]; then
    echo "ERROR: AZ_RESOURCE_GROUP_COMMON is not defined. Please check the .env file." >&2
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please define CLUSTER_NAME." >&2
    exit 1
fi

#######################################################################################
### Set default values for optional input
###

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Prepare az session
###

printf "\nLogging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Ask user to verify inputs and az login
###

echo -e ""
echo -e "Start deleting of orphaned DNS records using the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_DNS                  : $AZ_RESOURCE_DNS"
echo -e "   -  AZ_RESOURCE_GROUP_COMMON         : $AZ_RESOURCE_GROUP_COMMON"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

while true; do
    read -p "Is this correct? (Y/n) " yn
    case $yn in
        [Yy]* ) echo ""; break;;
        [Nn]* ) echo ""; echo "Please use 'az login' command to login to the correct account. Quitting."; exit 0;;
        * ) echo "Please answer yes or no.";;
    esac
done

# Get all txt records bound to the cluster.
printf "Get TXT records bound to ${CLUSTER_NAME}..."

TXT_RECORDS=$(az network dns record-set txt list \
    --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
    --zone-name ${AZ_RESOURCE_DNS} \
    --subscription ${AZ_SUBSCRIPTION_ID} \
    --query "[?contains(to_string(txtRecords[].value[]),'external-dns/owner=${CLUSTER_NAME}')].name" \
    --output tsv)

printf " Done.\n"

# Delete TXT and A records bound to cluster.
echo "Deleting TXT and A records"

function delete_dns_entries() {
    local dns_record=${1}
    echo "Delete for ${dns_record}..."
    az network dns record-set txt delete \
        --name $dns_record \
        --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
        --zone-name ${AZ_RESOURCE_DNS} \
        --yes
    az network dns record-set a delete \
        --name $dns_record \
        --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
        --zone-name ${AZ_RESOURCE_DNS} \
        --yes
    echo "Deleted ${dns_record}."
}

while read -r line; do
    if [[ "$line" ]]; then
        delete_dns_entries "${line}" &
    fi
done <<< "${TXT_RECORDS}"
wait

echo "Deleted DNS records for cluster."
