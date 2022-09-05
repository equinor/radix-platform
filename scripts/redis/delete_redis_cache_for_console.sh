#!/usr/bin/env bash

# PURPOSE
# Deletes the redis cache for the cluster given the context.

# Example 1:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-42" RADIX_WEB_CONSOLE_ENV="qa" ./delete_redis_cache_for_console.sh

# Example 2:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-49" RADIX_WEB_CONSOLE_ENV="prod" USER_PROMPT="false" ./delete_redis_cache_for_console.sh

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file
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

if [[ -z "$RADIX_WEB_CONSOLE_ENV" ]]; then
    echo "ERROR: Please provide RADIX_WEB_CONSOLE_ENV." >&2
    exit 1
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

function deleteRedisCache() {
    # check if redis cache exist, else exit
    echo ""
    REDIS_CACHE_NAME="$CLUSTER_NAME-$RADIX_WEB_CONSOLE_ENV"
    if [[ $(az redis show --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$REDIS_CACHE_NAME" 2>/dev/null) == "" ]]; then
        echo "ERROR: Redis Cache \"$REDIS_CACHE_NAME\" not found." >&2
        exit 1 # redis cache not found, exit
    fi

    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -r -p "Do you want to delete Redis Cache \"$REDIS_CACHE_NAME\"? (Y/n) " yn
            case $yn in
                [Yy]* ) echo ""; break;;
                [Nn]* ) echo "Quitting."; exit 0;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

    printf "Deleting Redis Cache \"%s\"..." "$REDIS_CACHE_NAME"
    if [[ $(az redis delete --yes --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$REDIS_CACHE_NAME" 2>&1) == *"ERROR"* ]]; then
        printf "\nERROR: Could not delete Redis Cache \"%s\".\n" "$REDIS_CACHE_NAME" >&2
    else
        printf " Done.\n"
    fi
}

deleteRedisCache
