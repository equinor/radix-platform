#!/usr/bin/env bash

#######################################################################################
### HOW TO USE
### 

# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env ./create_app_registration.sh

#######################################################################################
### Read inputs and configs
###

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

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

function create_app_registration() {
    az ad app create --display-name "$APP_REGISTRATION_WEB_CONSOLE"
}

create_app_registration