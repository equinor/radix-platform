#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Update App registration with API permissions

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV   : Path to *.env file
# - PERMISSIONS      : Ex: {"api": "Microsoft Graph","permissions": ["User.Read","GroupMember.Read.All"]}

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env PERMISSIONS='{"api": "Microsoft Graph","permissions": ["User.Read","GroupMember.Read.All"]}' ./update_app_registration_permissions.sh

#######################################################################################
### Check for prerequisites binaries
###

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

echo ""
printf "Check for neccesary executables... \n"
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... \n" >&2
    exit 1
}

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.41.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI.${normal}\n"
    exit 1
fi

printf "Done.\n"

#######################################################################################
### Read inputs and configs
###

# Required inputs

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

if [[ -z "$PERMISSIONS" ]]; then
    echo "ERROR: Please provide PERMISSIONS" >&2
    exit 1
fi

function update_app_registration_permissions() {
    APP_REGISTRATION_ID="$(az ad sp list --display-name "${APP_REGISTRATION_WEB_CONSOLE}" --query [].appId --output tsv 2>/dev/null)"
    if [ -z "$APP_REGISTRATION_ID" ]; then
        printf "    Could not find app registration. Exiting...\n"
        return
    fi
    CURRENT_API_PERMISSIONS="$(az ad app permission list --id "$APP_REGISTRATION_ID")"

    while read -r i; do
        API_NAME=$(jq -n "$i" | jq -r '.api')
        API_ID="$(az ad sp list --filter "displayname eq '$API_NAME'" | jq -r .[].appId)"
        API_PERMISSIONS=$(jq -n "$i" | jq -r '.permissions')

        if [ -z "$API_ID" ]; then
            printf "    Could not get API_ID. Exiting...\n"
            return
        fi
        if [ -z "$API_PERMISSIONS" ]; then
            printf "    API permissions missing. Exiting...\n"
            return
        fi

        while read -r i; do
            PERMISSION_NAME=$(jq -n "$i" | jq -r .)
            PERMISSION_ID="$(az ad sp show --id "$API_ID" --query "oauth2PermissionScopes[?value=='$PERMISSION_NAME'].id" --output tsv)"
            CHECK_DUPLICATION=$(jq -n "$CURRENT_API_PERMISSIONS" | jq -r ".[] | .resourceAccess[] | select(.id == \"$PERMISSION_ID\") | .id")

            if [ -z "$PERMISSION_ID" ]; then
                printf "    Permission id missing. Exiting...\n"
                return
            fi
            if [ -z "$CHECK_DUPLICATION" ]; then
                printf "    Adding %s %s to %s..." "$API_NAME" "$PERMISSION_NAME" "$APP_REGISTRATION_WEB_CONSOLE"
                az ad app permission add \
                    --id "$APP_REGISTRATION_ID" \
                    --api "$API_ID" \
                    --api-permissions "$PERMISSION_ID=Scope" \
                    --only-show-errors
                printf "Done.\n"
            else
                printf "    %s %s exist...skipping...\n" "$API_NAME" "$PERMISSION_NAME"
            fi

        done < <(echo "${API_PERMISSIONS[@]}" | jq -c '.[]')

    done < <(echo "${PERMISSIONS[@]}" | jq -c '.')
}

printf "Updating app registration permission for %s\n" "$APP_REGISTRATION_WEB_CONSOLE"
update_app_registration_permissions
printf "Done.\n"
