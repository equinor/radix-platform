#!/usr/bin/env bash

# PURPOSE
# Configures the auth proxy for the cluster given the context.

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env DEST_CLUSTER="weekly-50" RADIX_WEB_CONSOLE_ENV="qa" ./update_auth_proxy_secret_for_console.sh
#

# INPUTS:
#   DEST_CLUSTER          (Mandatory)
#   RADIX_ZONE_ENV          (Mandatory)
#   RADIX_WEB_CONSOLE_ENV   (Mandatory)

echo ""
echo "Updating auth-proxy secret for the radix web console"

# Validate mandatory input

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

if [[ -z "RADIX_WEB_CONSOLE_ENV" ]]; then
    echo "ERROR: Please provide RADIX_WEB_CONSOLE_ENV." >&2
    exit 1
fi


if [[ -z "$DEST_CLUSTER" ]]; then
    echo "ERROR: Please provide DEST_CLUSTER" >&2
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
verify_cluster_access

#######################################################################################
AUTH_PROXY_COMPONENT="web-aux-oauth"

function updateAuthProxySecret() {
    SECRETNAME="radix-web-console-client-secret"
    WEB_CONSOLE_NAMESPACE="radix-web-console-${RADIX_WEB_CONSOLE_ENV}"
    WEB_CONSOLE_AUTH_SECRET_NAME=$(kubectl --context "$DEST_CLUSTER" get secret -l "radix-aux-component=web,radix-aux-component-type=oauth" --namespace "${WEB_CONSOLE_NAMESPACE}" --output json | jq -r '.items[0].metadata.name')

    OAUTH2_PROXY_CLIENT_SECRET=$(az keyvault secret show --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${SECRETNAME}" | jq -r '.value')
    OAUTH2_PROXY_COOKIE_SECRET=$(python3 -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(16)).decode())')

    AUTH_SECRET_ENV_FILE="auth_secret.env"

    echo "ClientSecret=$OAUTH2_PROXY_CLIENT_SECRET" >>"$AUTH_SECRET_ENV_FILE"
    echo "CookieSecret=$OAUTH2_PROXY_COOKIE_SECRET" >>"$AUTH_SECRET_ENV_FILE"

    kubectl --context "$DEST_CLUSTER" patch secret "$WEB_CONSOLE_AUTH_SECRET_NAME" --namespace "$WEB_CONSOLE_NAMESPACE" \
        --patch "$(kubectl --context "$DEST_CLUSTER" create secret generic "$WEB_CONSOLE_AUTH_SECRET_NAME" --namespace "$WEB_CONSOLE_NAMESPACE" --save-config --from-env-file="$AUTH_SECRET_ENV_FILE" --dry-run=client -o yaml)"

    rm radix-web-console-client-secret.yaml
    rm "$AUTH_SECRET_ENV_FILE"

    echo "Auth proxy secret updated"
}

function updateRedisCachePasswordConfiguration() {
    if [[ $RADIX_ZONE == "prod" ]]; then
        # TODO: Remove special case for platform
        REDIS_CACHE_NAME="radix-platform-${RADIX_WEB_CONSOLE_ENV}"
        REDIS_RESOURCE_GROUP="clusters-platform"
    else
        REDIS_CACHE_NAME="radix-${RADIX_ZONE}-${RADIX_WEB_CONSOLE_ENV}"
        REDIS_RESOURCE_GROUP="${AZ_RESOURCE_GROUP_CLUSTERS}"
    fi

    echo "Updating Web Console in ${RADIX_WEB_CONSOLE_ENV} with Redis Cache ${REDIS_CACHE_NAME}..."

    WEB_CONSOLE_NAMESPACE="radix-web-console-${RADIX_WEB_CONSOLE_ENV}"
    WEB_CONSOLE_AUTH_SECRET_NAME=$(kubectl --context "$DEST_CLUSTER" get secret -l "radix-aux-component=web,radix-aux-component-type=oauth" --namespace "${WEB_CONSOLE_NAMESPACE}" --output json | jq -r '.items[0].metadata.name')
    OAUTH2_PROXY_REDIS_PASSWORD=$(az redis list-keys --resource-group "${REDIS_RESOURCE_GROUP}" --name "${REDIS_CACHE_NAME}" | jq -r .primaryKey)
    REDIS_ENV_FILE="redis_secret_${REDIS_CACHE_NAME}.env"

    echo "RedisPassword=${OAUTH2_PROXY_REDIS_PASSWORD}" >> "${REDIS_ENV_FILE}"

    kubectl --context "$DEST_CLUSTER" patch secret "${WEB_CONSOLE_AUTH_SECRET_NAME}" \
        --namespace "${WEB_CONSOLE_NAMESPACE}" \
        --patch "$(kubectl create secret generic "${WEB_CONSOLE_AUTH_SECRET_NAME}" --namespace "${WEB_CONSOLE_NAMESPACE}" --save-config --from-env-file="${REDIS_ENV_FILE}" --dry-run=client --output yaml)"

    rm "${REDIS_ENV_FILE}"

    echo "Redis Cache secrets updated"
}

### MAIN
updateAuthProxySecret
updateRedisCachePasswordConfiguration

printf "Restarting web deployment in %s..." "${WEB_CONSOLE_NAMESPACE}"
kubectl --context "$DEST_CLUSTER" rollout restart deployment --namespace "${WEB_CONSOLE_NAMESPACE}" "web-aux-oauth"
printf " Done.\n"
