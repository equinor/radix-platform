#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap radix-cr-cicd-dev/radix-cr-cicd-prod in a radix cluster

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap-acr.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap of radix-sp-acr-azure secret and radix-docker secret"

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2
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

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Verify cluster access
###
verify_cluster_access

az keyvault secret download \
    --vault-name "$AZ_RESOURCE_KEYVAULT" \
    --name "${AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD}" \
    --file sp_credentials.json

kubectl create secret generic radix-sp-acr-azure --from-file=sp_credentials.json --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry radix-docker \
    --docker-server="$AZ_RESOURCE_CONTAINER_REGISTRY.azurecr.io" \
    --docker-username="$(jq -r '.id' sp_credentials.json)" \
    --docker-password="$(jq -r '.password' sp_credentials.json)" \
    --docker-email=radix@statoilsrm.onmicrosoft.com \
    --dry-run=client -o yaml |
    kubectl apply -f -

rm -f sp_credentials.json

printf "\nDone\n"
