#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Update clusterlist in Keyvault

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

# Check cluster list:
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./clusterlist.sh


#######################################################################################
### START
###

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

hash uuidgen 2>/dev/null || {
    echo -e "\nERROR: uuidgen not found in PATH. Exiting..." >&2
    exit 1
}
#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "${RADIX_ZONE_ENV}" ]]; then
    printf "\nERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "${RADIX_ZONE_ENV}" ]]; then
        printf "\nERROR: RADIX_ZONE_ENV=%s is invalid, the file does not exist." "${RADIX_ZONE_ENV}" >&2
        exit 1
    fi
    source "${RADIX_ZONE_ENV}"
fi

# Optional inputs

if [[ -z "${USER_PROMPT}" ]]; then
    USER_PROMPT=true
fi

# Define script variables

SECRET_NAME="radix-clusters"
update_keyvault=false

#######################################################################################
### Prepare az session
###

printf "\nLogging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "${AZ_SUBSCRIPTION_ID}" >/dev/null
printf "Done.\n"

#######################################################################################
### Functions
###

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/lib_clusterlist.sh

#######################################################################################
### Prepare K8S CLUSTER LIST
###

K8S_CLUSTER_LIST=$(az keyvault secret show \
    --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${SECRET_NAME}" \
    --query="value" \
    --output tsv | jq '{clusters:.clusters | sort_by(.name | ascii_downcase)}' 2>/dev/null)
temp_file_path="/tmp/$(uuidgen)"
run-interactive-ip-clusters-wizard "${K8S_CLUSTER_LIST}" "${temp_file_path}" "${USER_PROMPT}"
new_master_k8s_api_ip_whitelist_base64=$(cat ${temp_file_path})
new_master_k8s_api_ip_whitelist=$(echo ${new_master_k8s_api_ip_whitelist_base64} | base64 -d)
rm ${temp_file_path}
if [[ ${update_keyvault} == true ]]; then
    EXPIRY_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ" --date="$KV_EXPIRATION_TIME")

    printf "\nUpdating keyvault \"%s\"... " "${AZ_RESOURCE_KEYVAULT}"
    if [[ "$(az keyvault secret set --name "${SECRET_NAME}" --vault-name "${AZ_RESOURCE_KEYVAULT}" --value "${new_master_k8s_api_ip_whitelist}" --expires "$EXPIRY_DATE" 2>&1)" == *"ERROR"* ]]; then
        printf "\nERROR: Could not update secret in keyvault \"%s\". Exiting..." "${AZ_RESOURCE_KEYVAULT}" >&2
        exit 1
    fi
    printf "Done.\n"
fi