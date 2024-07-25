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
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=weekly-44 ./bootstrap-acr.sh

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

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
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

# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 0
}
printf "...Done.\n"

verify_cluster_access

printf "Installing registry sp secret in k8s cluster...\n"

az keyvault secret download \
    --vault-name "$AZ_COMMON_KEYVAULT" \
    --name "${AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD}" \
    --file sp_credentials.json

# create secret for authenticating to ACR via az cli
# kubectl create secret generic radix-sp-acr-azure --from-file=sp_credentials.json --dry-run=client -o yaml | kubectl apply -f -

# create secret for authenticating to ACR via buildah client (same value as other ACR secret)
# username="$(jq .id sp_credentials.json --raw-output)"
# password="$(jq .password sp_credentials.json --raw-output)"
# kubectl create secret generic radix-sp-buildah-azure \
#     --from-literal=username=$username \
#     --from-literal=password=$password \
#     --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry radix-docker \
    --docker-server="$AZ_RESOURCE_CONTAINER_REGISTRY.azurecr.io" \
    --docker-username="$(jq -r '.id' sp_credentials.json)" \
    --docker-password="$(jq -r '.password' sp_credentials.json)" \
    --docker-email=radix@statoilsrm.onmicrosoft.com \
    --dry-run=client -o yaml |
    kubectl apply -f -

rm -f sp_credentials.json

printf "\nDone\n"

### Adding buildah cache repo secret

printf "Installing app registry secret in k8s cluster...\n"

az keyvault secret download \
    --vault-name "$AZ_COMMON_KEYVAULT" \
    --name "${AZ_SYSTEM_USER_APP_REGISTRY_SECRET_KEY}" \
    --file acr_password.json

# create secret for authenticating to ACR via buildah client (same value as other ACR secret)
acr_password="$(cat acr_password.json )"

kubectl create secret generic radix-app-registry \
    --from-literal="username=$AZ_SYSTEM_USER_APP_REGISTRY_USERNAME" \
    --from-literal="password=$acr_password" \
    --dry-run=client -o yaml |
    kubectl apply -f -
rm -f acr_password.json

printf "\nDone\n"
