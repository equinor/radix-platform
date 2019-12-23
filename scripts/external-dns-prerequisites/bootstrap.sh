#!/bin/bash

#######################################################################################
### PURPOSE
###

# Bootstrap prerequisites for external-dns (flux handles the main installation)

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
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start prerequisites for external-dns..."

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nError: Azure-CLI not found in PATH. Exiting..."
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nError: kubectl not found in PATH. Exiting..."
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nError: jq not found in PATH. Exiting..."
    exit 1
}
printf "All is good."
echo ""

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

az keyvault secret download \
    --vault-name $AZ_RESOURCE_KEYVAULT \
    --name external-dns-azure-secret \
    --file external-dns-azure-secret.yaml

kubectl apply -f external-dns-azure-secret.yaml

rm -f external-dns-azure-secret.yaml
