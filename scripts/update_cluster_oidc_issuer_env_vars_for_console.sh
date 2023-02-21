#!/usr/bin/env bash

# PURPOSE
# Sets CLUSTER_OIDC_ISSUER_URL environment variable of Radix Web Console with value in oidcIssuerProfile.issuerUrl assigned to the AKS cluster.

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-1" ./update_cluster_oidc_issuer_env_vars_for_console.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-1" ./update_cluster_oidc_issuer_env_vars_for_console.sh)
#

# INPUTS:
#   CLUSTER_NAME            (Mandatory)
#   RADIX_ZONE_ENV          (Mandatory)

# Optional:
# - STAGING         : Whether or not to use staging certificate. true/false. Default false.

#######################################################################################
### Check for prerequisites binaries
###

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.41.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI.${normal}\n"
    exit 1
fi

printf "Done.\n"

#######################################################################################
### Read inputs and configs
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

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME." >&2
    exit 1
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/lib_radix_api.sh

# Optional inputs

if [[ -z "$STAGING" ]]; then
    STAGING=false
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 1
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###

verify_cluster_access

### MAIN

cluster_oidc_issuer_url=$(az aks show --resource-group=$AZ_RESOURCE_GROUP_CLUSTERS --name=$CLUSTER_NAME  --query=oidcIssuerProfile.issuerUrl --output tsv) || exit

printf "Getting resource to be used to get access token for requests to Radix API..."
resource=$(echo "${OAUTH2_PROXY_SCOPE}" | awk '{print $4}' | sed 's/\/.*//')
if [[ -z ${resource} ]]; then
    echo "ERROR: Could not get Radix API access token resource." >&2
    exit
fi
printf " Done.\n"

updateComponentEnvVar "${resource}" "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-web-console" "qa" "web" "CLUSTER_OIDC_ISSUER_URL" "${cluster_oidc_issuer_url}" STAGING="$STAGING" || exit
updateComponentEnvVar "${resource}" "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-web-console" "prod" "web" "CLUSTER_OIDC_ISSUER_URL" "${cluster_oidc_issuer_url}" STAGING="$STAGING" || exit

# Restart Radix Web Console deployment
printf "Restarting Radix Web Console...\n"
kubectl rollout restart deployment -n radix-web-console-qa web
kubectl rollout restart deployment -n radix-web-console-prod web

echo "Done."
