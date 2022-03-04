#!/usr/bin/env bash

# PURPOSE
# Configures the redis cache for the cluster given the context.

# Example 1:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env AUTH_PROXY_COMPONENT="auth" CLUSTER_NAME="weekly-42" RADIX_WEB_CONSOLE_ENV="qa" ./update_redis_cache_for_console.sh

# Example 2:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env AUTH_PROXY_COMPONENT="auth" CLUSTER_NAME="weekly-49" RADIX_WEB_CONSOLE_ENV="prod" USER_PROMPT="false" ./update_redis_cache_for_console.sh

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file
# - AUTH_PROXY_COMPONENT    : Auth Component name, ex: "auth"
# - CLUSTER_NAME            : Cluster name, ex: "test-2", "weekly-93"
# - RADIX_WEB_CONSOLE_ENV   : Web Console Environment, ex: "qa", "prod"

# Optional:
# - USER_PROMPT             : Enable/disable user prompt, ex: "true" [default], "false"

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

if [[ -z "$AUTH_PROXY_COMPONENT" ]]; then
    echo "Please provide AUTH_PROXY_COMPONENT."
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME."
    exit 1
fi

if [[ -z "$RADIX_WEB_CONSOLE_ENV" ]]; then
    echo "Please provide RADIX_WEB_CONSOLE_ENV."
    exit 1
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
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
printf "\nConnecting kubectl..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS"  --name "$CLUSTER_NAME" 2>&1)"" == *"ERROR"* ]]; then    
    # Send message to stderr
    echo -e "Error: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 1        
fi
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
printf "Verifying cluster access..."
if [[ $(kubectl cluster-info 2>&1) == *"Unable to connect to the server"* ]]; then
    printf "ERROR: Could not access cluster. Quitting...\n"
    exit 1
fi
printf " OK\n"

#######################################################################################

function updateRedisCacheConfiguration() {
    # check if redis cache exist, else create new
    REDIS_CACHE_NAME="$CLUSTER_NAME-$RADIX_WEB_CONSOLE_ENV"
    REDIS_CACHE_INSTANCE=$(az redis show --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$REDIS_CACHE_NAME" 2>/dev/null)
    if [[ $REDIS_CACHE_INSTANCE == "" ]]; then
        echo "Info: Redis Cache \"$REDIS_CACHE_NAME\" not found."

        if [[ $USER_PROMPT == true ]]; then
            while true; do
                read -p "Do you want to create a new Redis Cache? (Y/n) " yn
                case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) echo "Quitting."; exit 1;; # no redis cache available, exit
                    * ) echo "Please answer yes or no.";;
                esac
            done
        fi

        printf "Creating new Redis Cache..."
        REDIS_CACHE_INSTANCE=$(az redis create \
            --location "$AZ_INFRASTRUCTURE_REGION" \
            --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" \
            --name "$REDIS_CACHE_NAME" \
            --sku Standard \
            --vm-size c1 \
            2>/dev/null)

        if [[ $REDIS_CACHE_INSTANCE == "" ]]; then
            echo ""
            echo "Error: Could not create Redis Cache. Quitting."
            exit 1
        fi
        printf " Done.\n"
    fi

    WEB_CONSOLE_NAMESPACE="radix-web-console-$RADIX_WEB_CONSOLE_ENV"
    WEB_CONSOLE_AUTH_SECRET_NAME=$(kubectl get secret -l radix-component="$AUTH_PROXY_COMPONENT" -n "$WEB_CONSOLE_NAMESPACE" -o=jsonpath=‘{.items[0].metadata.name}’ | sed 's/‘/ /g;s/’/ /g' | tr -d '[:space:]')
    OAUTH2_PROXY_REDIS_CONNECTION_URL="rediss://"$(jq -r '"\(.hostName):\(.sslPort)"' <<< $REDIS_CACHE_INSTANCE)
    OAUTH2_PROXY_REDIS_PASSWORD=$(az redis list-keys --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$REDIS_CACHE_NAME" | jq -r .primaryKey)
    REDIS_ENV_FILE="redis_secret.env"

    echo "OAUTH2_PROXY_REDIS_CONNECTION_URL=$OAUTH2_PROXY_REDIS_CONNECTION_URL" >> "$REDIS_ENV_FILE"
    echo "OAUTH2_PROXY_REDIS_PASSWORD=$OAUTH2_PROXY_REDIS_PASSWORD" >> "$REDIS_ENV_FILE"

    kubectl patch secret "$WEB_CONSOLE_AUTH_SECRET_NAME" --namespace "$WEB_CONSOLE_NAMESPACE" \
        --patch "$(kubectl create secret generic "$WEB_CONSOLE_AUTH_SECRET_NAME" --namespace "$WEB_CONSOLE_NAMESPACE" --save-config --from-env-file="$REDIS_ENV_FILE" --dry-run=client -o yaml)"

    rm "$REDIS_ENV_FILE"

    echo "Redis Cache secrets updated"

    printf "Restarting auth deployment..."
    kubectl rollout restart deployment -n "$WEB_CONSOLE_NAMESPACE" "$AUTH_PROXY_COMPONENT"
    printf " Done.\n"
}

updateRedisCacheConfiguration
