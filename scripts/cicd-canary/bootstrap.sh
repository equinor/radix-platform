#!/bin/bash

#######################################################################################
### PURPOSE
###

# Bootstrap radix-cicd-canary in a radix cluster

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin
# - Helm RBAC is configured in cluster
# - Tiller is installed in cluster (if using Helm version < 2)

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
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap of radix-cicd-canary... "

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

# Optional inputs

echo "Install Radix CICD Canary"
az keyvault secret download \
    --vault-name "$AZ_RESOURCE_KEYVAULT" \
    --name radix-cicd-canary-values \
    --file radix-cicd-canary-values.yaml

echo "clusterType: $CLUSTER_TYPE" >>radix-cicd-canary-values.yaml
echo "clusterFqdn: $CLUSTER_NAME.$AZ_RESOURCE_DNS" >>radix-cicd-canary-values.yaml

kubectl create ns radix-cicd-canary --dry-run=client --save-config -o yaml |
    kubectl apply -f -

kubectl create secret generic canary-secrets --namespace radix-cicd-canary \
    --from-file=./radix-cicd-canary-values.yaml \
    --dry-run=client -o yaml |
    kubectl apply -f -

rm -f radix-cicd-canary-values.yaml
echo "Done."
