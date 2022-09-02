#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# - Delete TXT Records not bound to a cluster.
# - Delete A Records with no corresponding TXT Record.

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
# RADIX_ZONE_ENV=aa.env ./delete_orphaned_dns_entries.sh

# Example: Delete from dev
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./delete_orphaned_dns_entries.sh

# Example: Delete from playground
# RADIX_ZONE_ENV=../radix-zone/radix_zone_playground.env ./delete_orphaned_dns_entries.sh

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
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Is this correct? (Y/n) " yn
        case $yn in
            [Yy]* ) echo ""; break;;
            [Nn]* ) echo ""; echo "Please use 'az login' command to login to the correct account. Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

printf "Getting list of aks clusters..."
CLUSTERS="$(az aks list --subscription ${AZ_SUBSCRIPTION_ID} | jq --raw-output -r '.[].name')"
printf " Done.\n"

printf "Get TXT records..."

TXT_RECORD_LIST=$(az network dns record-set txt list \
    --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
    --zone-name ${AZ_RESOURCE_DNS} \
    --subscription ${AZ_SUBSCRIPTION_ID} \
    --query "[].[name,to_string(txtRecords[].value[])]" -otsv)

printf " Done.\n"

function delete_txt_record() {
    local record_name=${1}
    local heritage=${2}
    echo "Deleting: $record_name (heritage: $heritage)..."
    az network dns record-set txt delete \
        --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
        --zone-name ${AZ_RESOURCE_DNS} \
        --name ${record_name} \
        --subscription ${AZ_SUBSCRIPTION_ID} \
        --yes
    echo "Deleted $record_name."
}

while IFS=$'\t' read -r -a line; do
    if [[ "$line" ]]; then
        record_name=${line[0]}
        record_value=${line[1]}
        # Split the record value into an array and get the heritage.
        IFS=',' read -r -a valueArray <<< "${line[1]}"
        heritage=${valueArray[1]#*=}
        if [[ ! "${CLUSTERS[*]}" =~ "${heritage}" || -z "${heritage}" ]]; then
            delete_txt_record "${record_name}" "${heritage}" &
        fi
    fi
done <<< "${TXT_RECORD_LIST}"
wait
unset IFS

echo "Deleted TXT-records not bound to a cluster."

EXCLUDE_LIST=(
    "@"
    "*.ext-mon"
)

printf "Get A-records..."

A_RECORD_LIST=$(az network dns record-set a list \
    --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
    --zone-name ${AZ_RESOURCE_DNS} \
    --subscription ${AZ_SUBSCRIPTION_ID} \
    --query "[].[name]" \
    --output tsv)

printf " Done.\n"

echo "Find A records not bound to a TXT-record..."

function delete_a_record() {
    local record_name=${1}
    echo "Deleting: $record_name..."
    az network dns record-set a delete \
        --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
        --zone-name ${AZ_RESOURCE_DNS} \
        --name ${record_name} \
        --subscription ${AZ_SUBSCRIPTION_ID} \
        --yes
    echo "Deleted ${record_name}."
}

while read -r line; do
    if [[ "$line" ]]; then
        if [[ ! "${TXT_RECORD_LIST[*]}" =~ "${line}" && ! ${EXCLUDE_LIST[*]} =~ "${line}" ]]; then
            delete_a_record "${line}" &
        fi
    fi
done <<< "${A_RECORD_LIST}"
wait

echo "Deleted A-records not bound to a TXT-record."

echo ""
echo "Deleted orphaned DNS records."
