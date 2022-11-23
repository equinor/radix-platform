#!/usr/bin/env bash

# PURPOSE
# Adds all Private IP Prefix IPs assigned to the Radix Zone to the environment variables of the web component of Radix Web Console.

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-1" ./update_env_vars_for_radix_api.sh
#
# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-1" ./update_env_vars_for_radix_api.sh)
#

# INPUTS:
#   CLUSTER_NAME            (Mandatory)
#   RADIX_ZONE_ENV          (Mandatory)

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

printf "Getting resource to be used to get access token for requests to Radix API..."
resource=$(echo "${OAUTH2_PROXY_SCOPE}" | awk '{print $4}' | sed 's/\/.*//')
if [[ -z ${resource} ]]; then
    echo "ERROR: Could not get Radix API access token resource." >&2
    exit
fi
printf " Done.\n"

updateComponentEnvVar "${resource}" "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "qa" "server" "REQUIRE_APP_CONFIGURATION_ITEM" "${RADIX_API_REQUIRE_APP_CONFIGURATION_ITEM}" || exit
updateComponentEnvVar "${resource}" "server-radix-api-prod.${CLUSTER_NAME}.${AZ_RESOURCE_DNS}" "radix-api" "prod" "server" "REQUIRE_APP_CONFIGURATION_ITEM" "${RADIX_API_REQUIRE_APP_CONFIGURATION_ITEM}" || exit

# Restart Radix API deployment
printf "Restarting Radix API...\n"
kubectl rollout restart deployment -n radix-api-qa server
kubectl rollout restart deployment -n radix-api-prod server

echo "Done."
