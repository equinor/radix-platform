#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Starting/stopping clusters in subscription

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - TASK                : Ex: "start", "stop"

#######################################################################################
### Read inputs and configs
###
echo ""
printf "Check for neccesary executables... "
hash acr 2>/dev/null || {
    echo -e "\nERROR: Azure ACR CLI not found in PATH. Exiting... " >&2
    exit 1
}

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

