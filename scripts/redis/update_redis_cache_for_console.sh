#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Configures the redis cache for the cluster given the context.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file
# - AUTH_PROXY_COMPONENT    : Auth Component name, ex: "auth"
# - CLUSTER_NAME            : Cluster name, ex: "test-2", "weekly-93"
# - RADIX_WEB_CONSOLE_ENV   : Web Console Environment, ex: "qa", "prod"

# Optional:
# - USER_PROMPT             : Enable/disable user prompt, ex: "true" [default], "false"

#######################################################################################
### HOW TO USE
###

# Example 1:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env AUTH_PROXY_COMPONENT="web" CLUSTER_NAME="weekly-42" RADIX_WEB_CONSOLE_ENV="qa" ./update_redis_cache_for_console.sh

# Example 2:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env AUTH_PROXY_COMPONENT="web" CLUSTER_NAME="weekly-49" RADIX_WEB_CONSOLE_ENV="prod" USER_PROMPT="false" ./update_redis_cache_for_console.sh

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

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}

printf "Done.\n"

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

if [[ -z "$AUTH_PROXY_COMPONENT" ]]; then
    echo "ERROR: Please provide AUTH_PROXY_COMPONENT." >&2
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME." >&2
    exit 1
fi

if [[ -z "$RADIX_WEB_CONSOLE_ENV" ]]; then
    echo "ERROR: Please provide RADIX_WEB_CONSOLE_ENV." >&2
    exit 1
fi

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Source util scripts

source "${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh"

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "${AZ_SUBSCRIPTION_ID}" >/dev/null
printf "Done.\n"

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "${AZ_RESOURCE_GROUP_CLUSTERS}" "${CLUSTER_NAME}" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"${CLUSTER_NAME}\" not found." >&2
    exit 0
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
verify_cluster_access

#######################################################################################

function updateRedisCachePasswordConfiguration() {
    if [[ $RADIX_ZONE == "prod" ]]; then
        # TODO: Remove special case for platform
        REDIS_CACHE_NAME="radix-platform-${RADIX_WEB_CONSOLE_ENV}"
        REDIS_RESOURCE_GROUP="clusters-platform"
    else
        REDIS_CACHE_NAME="radix-${RADIX_ZONE}-${RADIX_WEB_CONSOLE_ENV}"
        REDIS_RESOURCE_GROUP="${AZ_RESOURCE_GROUP_CLUSTERS}"
    fins

    echo "Updating Web Console in ${RADIX_WEB_CONSOLE_ENV} with Redis Cache ${REDIS_CACHE_NAME}..."

    WEB_CONSOLE_NAMESPACE="radix-web-console-${RADIX_WEB_CONSOLE_ENV}"
    WEB_CONSOLE_AUTH_SECRET_NAME=$(kubectl get secret -l "radix-aux-component=${AUTH_PROXY_COMPONENT},radix-aux-component-type=oauth" --namespace "${WEB_CONSOLE_NAMESPACE}" --output json | jq -r '.items[0].metadata.name')
    OAUTH2_PROXY_REDIS_PASSWORD=$(az redis list-keys --resource-group "${REDIS_RESOURCE_GROUP}" --name "${REDIS_CACHE_NAME}" | jq -r .primaryKey)
    REDIS_ENV_FILE="redis_secret_${REDIS_CACHE_NAME}.env"

    echo "RedisPassword=${OAUTH2_PROXY_REDIS_PASSWORD}" >> "${REDIS_ENV_FILE}"

    SECRETNAME="radix-web-console-auth"
    OAUTH_PROXY_CLIENT_SECRETNAME=$(az keyvault secret show -n $SECRETNAME --vault-name $AZ_RESOURCE_KEYVAULT | jq -r '.value')
    echo "OAUTH_PROXY_CLIENT_SECRETNAME=${OAUTH_PROXY_CLIENT_SECRETNAME}" >> "${REDIS_ENV_FILE}"

    kubectl patch secret "${WEB_CONSOLE_AUTH_SECRET_NAME}" \
        --dry-run=server
        --namespace "${WEB_CONSOLE_NAMESPACE}" \
        --patch "$(kubectl create secret generic "${WEB_CONSOLE_AUTH_SECRET_NAME}" --namespace "${WEB_CONSOLE_NAMESPACE}" --save-config --from-env-file="${REDIS_ENV_FILE}" --dry-run=client --output yaml)"

    rm "${REDIS_ENV_FILE}"

    echo "Redis Cache secrets updated"

    printf "Restarting %s deployment in %s..." "${AUTH_PROXY_COMPONENT}" "${WEB_CONSOLE_NAMESPACE}"
    kubectl rollout restart deployment --namespace "${WEB_CONSOLE_NAMESPACE}" "${AUTH_PROXY_COMPONENT}"
    printf " Done.\n"
}

updateRedisCacheConfiguration
