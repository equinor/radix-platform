#!/bin/bash

#######################################################################################
### PURPOSE
###

# Bootstrap radix-snyk-service-account in a radix cluster

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
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap-snyk.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap of radix-snyk-service-account secret"

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

echo "access-token=$(az keyvault secret show -n radix-snyk-sa-access-token-$RADIX_ZONE --vault-name $AZ_RESOURCE_KEYVAULT|jq -r '.value')
    " > radix-snyk-sa-access-token.yaml

kubectl create secret generic radix-snyk-service-account --from-env-file=radix-snyk-sa-access-token.yaml --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate secret radix-snyk-service-account kubed.appscode.com/sync='snyk-service-account-sync=radix-snyk-service-account'

rm -f radix-snyk-sa-access-token.yaml
