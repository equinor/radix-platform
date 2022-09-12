#!/usr/bin/env bash

# PURPOSE
# Configures the redis cache for the cluster given the context.

# Example 1:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env AUTH_PROXY_COMPONENT="auth" CLUSTER_NAME="weekly-42" RADIX_WEB_CONSOLE_ENV="qa" ./update_redis_cache_for_console.sh

# Example 2:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env AUTH_PROXY_COMPONENT="auth" CLUSTER_NAME="weekly-49" RADIX_WEB_CONSOLE_ENV="prod" USER_PROMPT="false" ./update_redis_cache_for_console.sh

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file
# - AUTH_PROXY_COMPONENT    : Auth Component name, ex: "auth"
# - CLUSTER_NAME            : Cluster name, ex: "test-2", "weekly-93"
# - RADIX_WEB_CONSOLE_ENV   : Web Console Environment, ex: "qa", "prod"

# Optional:
# - USER_PROMPT             : Enable/disable user prompt, ex: "true" [default], "false"

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

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
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
### CLUSTER?
###

kubectl_context="$(kubectl config current-context)"

if [ "$kubectl_context" = "$CLUSTER_NAME" ] || [ "$kubectl_context" = "${CLUSTER_NAME}" ]; then
    echo "kubectl is ready..."
else
    echo "ERROR: Please set your kubectl current-context to be ${CLUSTER_NAME}" >&2
    exit 1
fi

#######################################################################################
### Verify cluster access
###
verify_cluster_access

#######################################################################################

function updateRedisCacheConfiguration() {
    REDIS_CACHE_NAME="$CLUSTER_NAME-$RADIX_WEB_CONSOLE_ENV"
    REDIS_CACHE_INSTANCE=$(az redis show --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$REDIS_CACHE_NAME" 2>/dev/null)

    WEB_CONSOLE_NAMESPACE="radix-web-console-$RADIX_WEB_CONSOLE_ENV"
    WEB_CONSOLE_AUTH_SECRET_NAME=$(kubectl get secret -l radix-component="$AUTH_PROXY_COMPONENT" -n "$WEB_CONSOLE_NAMESPACE" -ojson | jq -r .items[0].metadata.name)
    OAUTH2_PROXY_REDIS_CONNECTION_URL="rediss://"$(jq -r '"\(.hostName):\(.sslPort)"' <<< $REDIS_CACHE_INSTANCE)
    OAUTH2_PROXY_REDIS_PASSWORD=$(az redis list-keys --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$REDIS_CACHE_NAME" | jq -r .primaryKey)
    REDIS_ENV_FILE="redis_secret_$REDIS_CACHE_NAME.env"

    echo "OAUTH2_PROXY_REDIS_CONNECTION_URL=$OAUTH2_PROXY_REDIS_CONNECTION_URL" >> "$REDIS_ENV_FILE"
    echo "OAUTH2_PROXY_REDIS_PASSWORD=$OAUTH2_PROXY_REDIS_PASSWORD" >> "$REDIS_ENV_FILE"

    kubectl patch secret "$WEB_CONSOLE_AUTH_SECRET_NAME" --namespace "$WEB_CONSOLE_NAMESPACE" \
        --patch "$(kubectl create secret generic "$WEB_CONSOLE_AUTH_SECRET_NAME" --namespace "$WEB_CONSOLE_NAMESPACE" --save-config --from-env-file="$REDIS_ENV_FILE" --dry-run=client -o yaml)"

    rm "$REDIS_ENV_FILE"

    echo "Redis Cache secrets updated"

    printf "Restarting $AUTH_PROXY_COMPONENT deployment in $WEB_CONSOLE_NAMESPACE..."
    kubectl rollout restart deployment -n "$WEB_CONSOLE_NAMESPACE" "$AUTH_PROXY_COMPONENT"
    printf " Done.\n"
}

updateRedisCacheConfiguration
