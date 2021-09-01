#!/bin/bash

#######################################################################################
### PURPOSE
###

# Bootstrap dynatrace in a radix cluster
# This script will: 
# - create the dynatrace namespace
# - retrieve the dynatrace secrets from the keyvault
# - store the secrets in a kubernetes secret

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin
# - Helm RBAC is configured in cluster
# - Following secrets in keyvault:
#       - dynatrace-api-url
#       - dynatrace-tenant-token (an API-token with config write permission)
#       - dynatrace-paas-token

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap of dynatrace... "

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
hash helm 2>/dev/null || {
    echo -e "\nError: helm not found in PATH. Exiting..."
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

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME" >&2
    exit 1
fi

echo "Get secrets from keyvault"

DYNATRACE_API_URL=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-api-url | jq -r .value)
DYNATRACE_API_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-tenant-token | jq -r .value)
DYNATRACE_PAAS_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-paas-token | jq -r .value)

if [[ -z "$DYNATRACE_API_URL" ]]; then
    echo "Please provide DYNATRACE_API_URL" >&2
    exit 1
fi
if [[ -z "$DYNATRACE_API_TOKEN" ]]; then
    echo "Please provide DYNATRACE_API_TOKEN" >&2
    exit 1
fi
if [[ -z "$DYNATRACE_PAAS_TOKEN" ]]; then
    echo "Please provide DYNATRACE_PAAS_TOKEN" >&2
    exit 1
fi

# Use the following release version of dynatrace-operator https://github.com/Dynatrace/dynatrace-operator/releases
RELEASE_VERSION="v0.2.2"

echo "Install Dynatrace"

sh ./install.sh \
    --api-url "${DYNATRACE_API_URL}" \
    --api-token "${DYNATRACE_API_TOKEN}" \
    --paas-token "${DYNATRACE_PAAS_TOKEN}" \
    --cluster-name "${CLUSTER_NAME}" \
    --skip-ssl-verification \
    --release-version "${RELEASE_VERSION}"

echo "Done."