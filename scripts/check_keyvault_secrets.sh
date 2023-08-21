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

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

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
if [[ $(uname) == "Darwin" ]]; then
    hash gdate 2>/dev/null || {
        echo -e "\nERROR: gdate not found in PATH. Exiting..." >&2
        exit 1
    }
fi
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
fmt="%-55s %-40s %5s\n"

KEY_VAULTS=$(az keyvault list)
SECRETS_MISSING_EXPIRY_DATE=()
SECRETS_EXPIRING_SOON=()
SECRETS_EXPIRED=()

function printSecrets() {
    SECRET_LIST=$1
    TEXT_COLOR=$2

    if [[ -z "$TEXT_COLOR" ]]; then
        TEXT_COLOR="${normal}"
    fi

    if [ ${#SECRET_LIST[@]} -ne 0 ]; then
        while read -r i; do
            NAME=$(jq -n "$i" | jq -r '.name')
            KEYVAULT=$(jq -n "$i" | jq -r '.keyvault')
            EXPIRES=$(jq -n "$i" | jq -r '.expires')

            printf "${TEXT_COLOR}"
            printf "${fmt}" "$NAME" "$KEYVAULT" "$EXPIRES"
            printf "${normal}"
        done < <(echo "${SECRET_LIST[@]}" | jq -c '.')
    fi
}

function checkForMissingExpiryDate() {
    while read -r i; do
        EXPIRES=$(jq -n "$i" | jq -r '.attributes.expires')
        NAME=$(jq -n "$i" | jq -r '.name')
        ID=$(jq -n "$i" | jq -r '.id')

        if [[ $EXPIRES == "null" ]]; then
            SECRETS_MISSING_EXPIRY_DATE+=("{\"name\":\"$NAME\",\"id\":\"$ID\",\"expires\":\"$EXPIRES\",\"keyvault\":\"$KV_NAME\"}")
        fi
    done < <(echo "${KV_SECRETS}" | jq -c '.[]')
}

function assignExpiryDate() {
    EXPIRY_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ" --date="$KV_EXPIRATION_TIME")
    SECRETS_ASSIGNED_EXPIRY_DATE=()

    printf "\nAssigning expiration date..."
    while read -r i; do
        EXPIRES=$(jq -n "$i" | jq -r '.expires')
        NAME=$(jq -n "$i" | jq -r '.name')
        ID=$(jq -n "$i" | jq -r '.id')
        KEYVAULT=$(jq -n "$i" | jq -r '.keyvault')

        if az keyvault secret set-attributes --id "$ID" --expires "$EXPIRY_DATE" --output none; then
            SECRETS_ASSIGNED_EXPIRY_DATE+=("{\"name\":\"$NAME\",\"id\":\"$ID\",\"expires\":\"$(date +%c --date="$EXPIRY_DATE")\",\"keyvault\":\"$KV_NAME\"}")
        fi

    done < <(echo "${SECRETS_MISSING_EXPIRY_DATE[@]}" | jq -c '.')

    if [ ${#SECRETS_ASSIGNED_EXPIRY_DATE[@]} -ne 0 ]; then
        printf "\n${fmt}" "Secret" "Keyvault" "Expiration"
        printSecrets "${SECRETS_ASSIGNED_EXPIRY_DATE[*]}" "${grn}"
    fi

    return 1
}

function compareDate() {
    TODAY=$(date +%s)
    EXPIRES=$(date +%s --date="$1")
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
                    SECRETS_EXPIRED+=("{\"name\":\"$NAME\",\"id\":\"$ID\",\"expires\":\"$(date +%c --date="$EXPIRES")\",\"keyvault\":\"$KV_NAME\"}")
                else
                    SECRETS_EXPIRING_SOON+=("{\"name\":\"$NAME\",\"id\":\"$ID\",\"expires\":\"$(date +%c --date="$EXPIRES")\",\"keyvault\":\"$KV_NAME\"}")
                fi
            fi
        fi
    done < <(echo "${KV_SECRETS}" | jq -c '.[]')
}

while read -r i; do
    KV_NAME=$(jq -n "$i" | jq -r '.name')
    printf "Getting secrets from keyvault %s... " "${KV_NAME}"

    KV_SECRETS=$(az keyvault secret list --vault-name "$KV_NAME" 2>/dev/null || {
        # Send message to stderr
        printf "ERROR: Could not get secrets for keyvault \"%s\". " "$KV_NAME" >&2
        exit 1
    })

    checkForMissingExpiryDate
    checkExpiryDates

    printf "Done.\n"
done < <(echo "${KEY_VAULTS}" | jq -c '.[]')

if [ ${#SECRETS_MISSING_EXPIRY_DATE[@]} -ne 0 ]; then
    printf "\nListing secrets missing expiration date...\n"
    printf "${fmt}" "Secret" "Keyvault"
    while read -r i; do
        NAME=$(jq -n "$i" | jq -r '.name')
        KEYVAULT=$(jq -n "$i" | jq -r '.keyvault')
        printf "${fmt}" "$NAME" "$KEYVAULT"
    done < <(echo "${SECRETS_MISSING_EXPIRY_DATE[@]}" | jq -c '.')

    printf "\n"

    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -r -p "Do you want to assign expiration date to the following secrets? $KV_EXPIRATION_TIME from today (Y/n) " yn
            case $yn in
            [Yy]*) assignExpiryDate || break ;;
            [Nn]*) break ;;
            *) echo "Please answer yes or no" ;;
            esac
        done
    else
        assignExpiryDate
    fi
fi

if [ ${#SECRETS_EXPIRING_SOON[@]} -ne 0 ] || [ ${#SECRETS_EXPIRED[@]} -ne 0 ]; then
    printf "\nListing soon to expire and expired secrets...\n"
    printf "${fmt}" "Secret" "Keyvault" "Expiration"
    printSecrets "${SECRETS_EXPIRING_SOON[*]}" "${yel}"
    printSecrets "${SECRETS_EXPIRED[*]}" "${red}"
fi

printf "\nDone\n"
