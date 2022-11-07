#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Create Azure Container Registry (ACR) Task
# This script will: 
# - create an ACR Task with a system-assigned identity
# - grant the Task system-assigned identity access to push to ACR
# - add credentials using the system-assigned identity to the task

#######################################################################################
### DOCS
###

# https://docs.microsoft.com/en-us/azure/container-registry/container-registry-tasks-authentication-managed-identity
# https://docs.microsoft.com/en-us/azure/container-registry/allow-access-trusted-services#example-acr-tasks

#######################################################################################
### PRECONDITIONS
###

# - ACR Exists

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix_zone_dev.env ./acr_task.sh

#######################################################################################
### START
###

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
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

if [[ -z "$AZ_RESOURCE_CONTAINER_REGISTRY" ]]; then
    echo "ERROR: AZ_RESOURCE_CONTAINER_REGISTRY not defined. Exiting..." >&2
    exit 1
fi

if [[ -z "$AZ_RESOURCE_ACR_TASK_NAME" ]]; then
    echo "ERROR: AZ_RESOURCE_ACR_TASK_NAME not defined. Exiting..." >&2
    exit 1
fi

if [[ -z "$AZ_RESOURCE_ACR_CACHE_TASK_NAME" ]]; then
    echo "ERROR: AZ_RESOURCE_ACR_CACHE_TASK_NAME not defined. Exiting..." >&2
    exit 1
fi

if [[ -z "$AZ_RESOURCE_ACR_BUILD_ONLY_TASK_NAME" ]]; then
    echo "ERROR: AZ_RESOURCE_ACR_BUILD_ONLY_TASK_NAME not defined. Exiting..." >&2
    exit 1
fi

if [[ -z "$AZ_RESOURCE_ACR_INTERNAL_TASK_NAME" ]]; then
    echo "ERROR: AZ_RESOURCE_ACR_INTERNAL_TASK_NAME not defined. Exiting..." >&2
    exit 1
fi

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

LIB_ACR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../radix-zone/base-infrastructure/lib_acr.sh"
if [[ ! -f "$LIB_ACR_PATH" ]]; then
    echo "ERROR: The dependency LIB_ACR_PATH=$LIB_ACR_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_ACR_PATH"
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
echo -e "Create ACR Task with the following configuration:"
echo -e ""
echo -e "   > WHAT:"
echo -e "   --------------------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_CONTAINER_REGISTRY       : $AZ_RESOURCE_CONTAINER_REGISTRY"
echo -e "   -  AZ_RESOURCE_ACR_TASK_NAME            : $AZ_RESOURCE_ACR_TASK_NAME"
echo -e "   -  AZ_RESOURCE_ACR_CACHE_TASK_NAME      : $AZ_RESOURCE_ACR_CACHE_TASK_NAME"
echo -e "   -  AZ_RESOURCE_ACR_BUILD_ONLY_TASK_NAME : $AZ_RESOURCE_ACR_BUILD_ONLY_TASK_NAME"
echo -e "   -  AZ_RESOURCE_ACR_INTERNAL_TASK_NAME   : $AZ_RESOURCE_ACR_INTERNAL_TASK_NAME"
echo -e "   -  AZ_RESOURCE_ACR_AGENT_POOL_NAME      : $AZ_RESOURCE_ACR_AGENT_POOL_NAME"
echo -e "   -  AZ_RESOURCE_ACR_AGENT_POOL_TIER      : $AZ_RESOURCE_ACR_AGENT_POOL_TIER"
echo -e "   -  AZ_RESOURCE_ACR_AGENT_POOL_COUNT     : $AZ_RESOURCE_ACR_AGENT_POOL_COUNT"
echo -e ""
echo -e "   > WHO:"
echo -e "   --------------------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                      : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                              : $(az account show --query user.name -o tsv)"
echo -e ""
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Is this correct? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    echo ""
fi



create_internal_acr_task "${AZ_RESOURCE_ACR_INTERNAL_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"
create_role_assignment "${AZ_RESOURCE_ACR_INTERNAL_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"
add_task_credential "${AZ_RESOURCE_ACR_INTERNAL_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"

create_agent_pool "${AZ_RESOURCE_ACR_AGENT_POOL_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}" "${AZ_RESOURCE_ACR_AGENT_POOL_TIER}" "${AZ_RESOURCE_ACR_AGENT_POOL_COUNT}"

create_acr_task "${AZ_RESOURCE_ACR_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}" "${AZ_RESOURCE_ACR_AGENT_POOL_NAME}"
create_role_assignment "${AZ_RESOURCE_ACR_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"
add_task_credential "${AZ_RESOURCE_ACR_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"

create_acr_task_with_cache "${AZ_RESOURCE_ACR_CACHE_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}" "${AZ_RESOURCE_ACR_AGENT_POOL_NAME}"
create_role_assignment "${AZ_RESOURCE_ACR_CACHE_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"
add_task_credential "${AZ_RESOURCE_ACR_CACHE_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}"

create_acr_task_build_only "${AZ_RESOURCE_ACR_BUILD_ONLY_TASK_NAME}" "${AZ_RESOURCE_CONTAINER_REGISTRY}" "${AZ_RESOURCE_ACR_AGENT_POOL_NAME}"

#run_task # Uncomment this line to test the task

echo ""
echo "Done creating ACR Tasks."
