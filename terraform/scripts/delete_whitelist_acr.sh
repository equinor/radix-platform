#!/usr/bin/env bash

#######################################################################################
### Read inputs and configs
###

WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RADIX_SCRIPTS_PATH="$WORKDIR_PATH/../../scripts"

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_SCRIPTS_PATH/$RADIX_ZONE_ENV" ]]; then
        echo "ERROR: RADIX_ZONE_ENV=$RADIX_SCRIPTS_PATH/$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    # source "$RADIX_SCRIPTS_PATH/$RADIX_ZONE_ENV"
fi

if [[ -z "$ACTION" ]]; then
    echo "ERROR: Please provide ACTION" >&2
    exit 1
fi

if [[ -z "$IP_MASK" ]]; then
    echo "ERROR: Please provide IP_MASK" >&2
    exit 1
fi

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=false
fi

#######################################################################################
### Resolve dependencies on other scripts
###

UPDATE_ACR_WHITELIST="$RADIX_SCRIPTS_PATH/acr/update_acr_whitelist.sh"
if ! [[ -x "$UPDATE_ACR_WHITELIST" ]]; then
    # Print to stderror
    echo "ERROR: The update ACR whitelist script is not found or it is not executable in path $UPDATE_ACR_WHITELIST" >&2
fi

#######################################################################################
### START
###

if [[ $MIGRATION_STRATEGY == "aa" ]]; then
    echo "Migration Strategy is AA skipping..."
else
    if [[ -z "$IP_MASK" ]]; then
        echo "Skipping..."
    else
        echo "Removing IP from ACR..."
        (RADIX_ZONE_ENV="$RADIX_SCRIPTS_PATH/$RADIX_ZONE_ENV" ACTION="$ACTION" IP_MASK="$IP_MASK" USER_PROMPT="$USER_PROMPT" source "$UPDATE_ACR_WHITELIST")
    fi
fi