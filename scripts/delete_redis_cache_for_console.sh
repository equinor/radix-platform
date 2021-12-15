#!/usr/bin/env bash

# PURPOSE
# Deletes the redis cache for the cluster given the context.

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file
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

function deleteRedisCache() {
    # check if redis cache exist, else exit
    if ! az redis show --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME-$RADIX_WEB_CONSOLE_ENV"; then
        echo "Warning: No matching Redis Cache found"
        exit 1 # redis cache not found, exit
    fi

    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -p "Do you want to delete Redis Cache [--resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME-$RADIX_WEB_CONSOLE_ENV"]? (Y/n) " yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) echo "Redis Cache not deleted"; exit 0;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

    echo "Deleting Redis Cache [--resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME-$RADIX_WEB_CONSOLE_ENV"]"
    if az redis delete --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME-$RADIX_WEB_CONSOLE_ENV"; then
        echo "Redis Cache deleted successfully"
    else
        echo "ERROR: An error occurred while deleting Redis Cache"
    fi
}

deleteRedisCache
