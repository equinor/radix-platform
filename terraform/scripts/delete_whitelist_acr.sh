#!/usr/bin/env bash

WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RADIX_SCRIPTS="$WORKDIR_PATH/../../scripts"

UPDATE_ACR_WHITELIST="$RADIX_SCRIPTS/acr/update_acr_whitelist.sh"
if ! [[ -x "$UPDATE_ACR_WHITELIST" ]]; then
    # Print to stderror
    echo "ERROR: The update ACR whitelist script is not found or it is not executable in path $UPDATE_ACR_WHITELIST" >&2
fi

if [[ $MIGRATION_STRATEGY == "aa" ]]; then
    echo "Migration Strategy is AA skipping..."
else
    echo "Removing IP from ACR..."
    (RADIX_ZONE_ENV="$RADIX_SCRIPTS/$RADIX_ZONE_ENV" ACTION="$ACTION" IP_MASK="$IP_MASK" USER_PROMPT="$USER_PROMPT" source "$UPDATE_ACR_WHITELIST")
fi