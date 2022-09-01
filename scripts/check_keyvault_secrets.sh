#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Warn about expiring secrets and assign expiration date if missing.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# Check keyvault
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env ./check_keyvault_secrets.sh

#######################################################################################
### Read inputs and configs
###

DAYS_LEFT_WARNING=14
EXPIRY_DATE_EXTENSION="6 months"

printf "\nStarting check keyvault secrets... "

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

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Check for prerequisites binaries
###

printf "\nCheck for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}
printf "Done.\n"

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Check keyvault secrets will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -r -p "Is this correct? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            echo ""
            echo "Quitting..."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    echo ""
fi

#######################################################################################
### Start
###

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

KEY_VAULT_SECRETS=$(az keyvault secret list --vault-name "$AZ_RESOURCE_KEYVAULT")
MISSING_EXPIRY_ARRAY=()

function createArrays() {
    while read -r i; do
        EXPIRES=$(jq -n "$i" | jq -r '.attributes.expires')
        NAME=$(jq -n "$i" | jq -r '.name')
        ID=$(jq -n "$i" | jq -r '.id')

        if [[ $EXPIRES == "null" ]]; then
            MISSING_EXPIRY_ARRAY+=("{\"name\":\"$NAME\",\"id\":\"$ID\",\"expires\":\"$EXPIRES\"}")
        fi
    done < <(echo "${KEY_VAULT_SECRETS}" | jq -c '.[]')
}

function assignExpiryDate() {
    NEXT_EXPIRY_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ" --date="$EXPIRY_DATE_EXTENSION")

    while read -r i; do
        EXPIRES=$(jq -n "$i" | jq -r '.expires')
        NAME=$(jq -n "$i" | jq -r '.name')
        ID=$(jq -n "$i" | jq -r '.id')

        if az keyvault secret set-attributes --id "$ID" --expires "$NEXT_EXPIRY_DATE" --output none; then
            printf "\n%s  Assigned secret %s expiry date %s%s" "${grn}" "$NAME" "$(date +%c -d "$NEXT_EXPIRY_DATE")" "${normal}"
        fi

    done < <(echo "${MISSING_EXPIRY_ARRAY[@]}" | jq -c '.')

    return 1
}

function compareDate() {
    TODAY=$(date +%s)
    EXPIRES=$(date +%s -d "$1")
    DIFFERANSE=$((("$EXPIRES" - "$TODAY") / 86400))
    echo "$DIFFERANSE"
}

function checkExpiryDates() {
    while read -r i; do
        EXPIRES=$(jq -n "$i" | jq -r '.attributes.expires')
        NAME=$(jq -n "$i" | jq -r '.name')
        ID=$(jq -n "$i" | jq -r '.id')

        if [[ $EXPIRES != "null" ]]; then
            local res=$(compareDate "$EXPIRES")
            DIFFERANSE=$res
            if [ "$DIFFERANSE" -lt $DAYS_LEFT_WARNING ]; then
                if [ "$DIFFERANSE" -lt 0 ]; then
                    printf "\n  %sSecret %s in keyvault %s has expired %s%s" "${red}" "$NAME" "$AZ_RESOURCE_KEYVAULT" "$(date +%c -d "$EXPIRES")" "${normal}"
                else
                    printf "\n  %sSecret %s in keyvault %s is expiring soon %s%s" "${yel}" "$NAME" "$AZ_RESOURCE_KEYVAULT" "$(date +%c -d "$EXPIRES")" "${normal}"
                fi
            fi
        fi
    done < <(echo "${KEY_VAULT_SECRETS}" | jq -c '.[]')
}

printf "Creating arrays..."
createArrays
printf "done"

if [ ${#MISSING_EXPIRY_ARRAY[@]} -ne 0 ]; then
    printf "\nChecking for missing expiration dates..."
    while read -r i; do
        NAME=$(jq -n "$i" | jq -r '.name')
        printf "\n%s  Secret %s is missing expiry date%s" "${yel}" "$NAME" "${normal}"
    done < <(echo "${MISSING_EXPIRY_ARRAY[@]}" | jq -c '.')

    printf "\n"

    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -r -p "Do you want to assign date to secrets missing expiry date? $EXPIRY_DATE_EXTENSION from today (y/N) " yn
            case $yn in
            [Yy]*) assignExpiryDate || break ;;
            [Nn]*) break ;;
            *) echo "Please answer yes or no" ;;
            esac
        done
    else
        assignExpiryDate
    fi
    printf "\nDone"
fi

printf "\nChecking expiration dates..."
checkExpiryDates
printf "\nDone\n"
