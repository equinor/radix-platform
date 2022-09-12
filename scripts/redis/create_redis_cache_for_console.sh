#!/usr/bin/env bash

# PURPOSE
# Creates the redis cache for the cluster given the context.

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

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME." >&2
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

function createRedisCache() {
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

        echo "Creating new Redis Cache. Running asynchronously..."
        #Docs https://azure.microsoft.com/en-us/pricing/details/cache/
        az deployment group create --no-wait --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --subscription "${AZ_SUBSCRIPTION_ID}" --template-file "${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/redis/azure_cache_for_redis.json" --name "redis-cache-${CLUSTER_NAME}-${RADIX_WEB_CONSOLE_ENV}" \
                --parameters name="${REDIS_CACHE_NAME}" \
                --parameters location="${AZ_RADIX_ZONE_LOCATION}" \
                --parameters sku="${AZ_REDIS_CACHE_SKU}"
    fi
}

createRedisCache
