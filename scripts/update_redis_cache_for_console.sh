#!/usr/bin/env bash

# PURPOSE
# Configures the redis cache for the cluster given the context.

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file
# - WEB_CONSOLE_NAMESPACE   : Ex: "radix-web-console-prod"
# - AUTH_PROXY_COMPONENT    : Auth Component name, ex: "auth"
# - CLUSTER_NAME            : Cluster name, ex: "test-2", "weekly-93"
# - CLUSTER_TYPE            : Cluster type, ex: "qa", "prod"

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

if [[ -z "$WEB_CONSOLE_NAMESPACE" ]]; then
    echo "Please provide WEB_CONSOLE_NAMESPACE."
    exit 1
fi

if [[ -z "$AUTH_PROXY_COMPONENT" ]]; then
    echo "Please provide AUTH_PROXY_COMPONENT."
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME."
    exit 1
fi

if [[ -z "$CLUSTER_TYPE" ]]; then
    echo "Please provide CLUSTER_TYPE."
    exit 1
fi

function updateRedisCacheConfiguration() {
    # check if redis cache exist, else create new
    if ! REDIS_CACHE_INSTANCE=$(az redis show --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME-$CLUSTER_TYPE"); then
        echo "Warning: Redis Cache not found"

        while true; do
            read -p "Do you want to create a new Redis Cache? (Y/n) " yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) echo "ERROR: No Redis Cache available!"; exit 1;; # no redis cache available, exit
                * ) echo "Please answer yes or no.";;
            esac
        done

        echo "Creating new Redis Cache"
        REDIS_CACHE_INSTANCE=$(az redis create --location "$AZ_INFRASTRUCTURE_REGION" --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME-$CLUSTER_TYPE" --sku Standard --vm-size c1)
    fi

    WEB_CONSOLE_AUTH_SECRET_NAME=$(kubectl get secret -l radix-component="$AUTH_PROXY_COMPONENT" -n "$WEB_CONSOLE_NAMESPACE" -o=jsonpath=‘{.items[0].metadata.name}’ | sed 's/‘/ /g;s/’/ /g' | tr -d '[:space:]')
    OAUTH2_PROXY_REDIS_CONNECTION_URL=$(jq -r '"\(.hostName):\(.sslPort)"' <<< $REDIS_CACHE_INSTANCE)
    OAUTH2_PROXY_REDIS_PASSWORD=$(az redis list-keys --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME-$CLUSTER_TYPE" | jq -r .secondaryKey)
    REDIS_ENV_FILE="redis_secret.env"

    echo "OAUTH2_PROXY_REDIS_CONNECTION_URL=$OAUTH2_PROXY_REDIS_CONNECTION_URL" >> "$REDIS_ENV_FILE"
    echo "OAUTH2_PROXY_REDIS_PASSWORD=$OAUTH2_PROXY_REDIS_PASSWORD" >> "$REDIS_ENV_FILE"

    kubectl create secret generic "$WEB_CONSOLE_AUTH_SECRET_NAME" --namespace "$WEB_CONSOLE_NAMESPACE" \
        --from-env-file="$REDIS_ENV_FILE" \
        --dry-run=client -o yaml |
        kubectl apply -f -

    rm "$REDIS_ENV_FILE"

    echo "Redis Cache secrets updated"

    printf "Restarting auth deployment..."
    kubectl rollout restart deployment -n $WEB_CONSOLE_NAMESPACE $AUTH_PROXY_COMPONENT
    printf " Done.\n"
}

updateRedisCacheConfiguration
