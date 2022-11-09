#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Kubernetes API server should be configured with restricted access.
# This script takes a list of IPs and updates the secret in the keyvault.
# If a cluster name is specified, then the k8s API server for the cluster will be updated.

# Default usage: Get whitelist from keyvault to pass in on cluster creation in aks bootstrap.
# Optional usage: Update the API whitelist of an existing cluster.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file

# Optional:
# - CLUSTER_NAME            : Name of cluster to update

#######################################################################################
### HOW TO USE
###

# Update the keyvault secret
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./update_api_server_whitelist.sh

# Update the keyvault secret and a cluster with the list
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" ./update_api_server_whitelist.sh

#######################################################################################
### START
###

#######################################################################################
### Check for prerequisites binaries
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

SECRET_NAME="kubernetes-api-server-whitelist-ips-${RADIX_ENVIRONMENT}"
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

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/lib_ip_whitelist.sh



#######################################################################################
### Prepare K8S API IP WHITELIST
###
MASTER_K8S_API_IP_WHITELIST=$(az keyvault secret show --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${SECRET_NAME}" --query="value" -otsv | base64 --decode | jq '{whitelist:.whitelist | sort_by(.location | ascii_downcase)}' 2>/dev/null)


# if [[ "${OSTYPE}" == "linux-gnu"* ]]; then
#     checkpackage=$( dpkg -s libnet-ip-perl /dev/null 2>&1 | grep Status: )
#     if [[ -n ${checkpackage} ]]; then
# fi

temp_file_path="/tmp/$(uuidgen)"
run-interactive-ip-whitelist-wizard "${MASTER_K8S_API_IP_WHITELIST}" "${temp_file_path}"
new_master_k8s_api_ip_whitelist_base64=$(cat ${temp_file_path})
new_master_k8s_api_ip_whitelist=$(echo ${new_master_k8s_api_ip_whitelist_base64} | base64 -d)

# clean up
rm ${temp_file_path}

#######################################################################################
### Get list of IPs
###

new_k8s_api_ip_whitelist=$(jq <<<"${new_master_k8s_api_ip_whitelist[@]}" | jq -r '[.whitelist[].ip] | join(",")')

#######################################################################################
### Update keyvault if input list
###

if [[ ${update_keyvault} == true ]]; then
    # Update keyvault
    printf "\nUpdating keyvault \"%s\"... " "${AZ_RESOURCE_KEYVAULT}"
    if [[ "$(az keyvault secret set --name "${SECRET_NAME}" --vault-name "${AZ_RESOURCE_KEYVAULT}" --value "${new_master_k8s_api_ip_whitelist_base64}" 2>&1)" == *"ERROR"* ]]; then
        printf "\nERROR: Could not update secret in keyvault \"%s\". Exiting..." "${AZ_RESOURCE_KEYVAULT}" >&2
        exit 1
    fi
    printf "Done.\n"
fi

#######################################################################################
### Update cluster
###

if [[ -n ${CLUSTER_NAME} ]]; then
    # Check if cluster exists
    printf "\nUpdate cluster \"%s\".\n" "${CLUSTER_NAME}"
    if [[ -n "$(az aks list --query "[?name=='${CLUSTER_NAME}'].name" --subscription "${AZ_SUBSCRIPTION_ID}" -otsv)" ]]; then
        printf "\nUpdating cluster with whitelist IPs...\n"
        if [[ $(az aks update --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" --name "${CLUSTER_NAME}" --api-server-authorized-ip-ranges "${new_k8s_api_ip_whitelist}") == *"ERROR"* ]]; then
            printf "ERROR: Could not update cluster. Quitting...\n" >&2
            exit 1
        fi
        printf "\nDone.\n"
    else
        printf "\nERROR: Could not find the cluster. Make sure you have access to it." >&2
        exit 1
    fi
fi
