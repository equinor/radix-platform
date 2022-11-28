#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Warn about expiring App registrations secrets

#######################################################################################
### INPUTS
###

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# App registrations secrets:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env ./check_appreg_secrets.sh

#######################################################################################
### Read inputs and configs
###

YELLOW_WARNING_DAYS=28
RED_WARNING_DAYS=14

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)
fmt="%-55s %-40s %5s\n"
fmt2="%-55s %-40s %5s\n"

printf "\nApp registrations secrets... "

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
### Functions
###

function check_applications() {
    while read -r i; do
        APPID=$(jq -n "${i}" | jq -r .appId)
        DISPLAYNAME=$(jq -n "${i}" | jq -r .displayName)
        list_secrets
    done < <(printf "%s" "${AZAPP}" | jq -c '.[]')
}

function list_secrets() {
    while read -r i; do
        SECRET_NAME=$(jq -n "${i}" | jq -r .displayName)
        EXPIRES=$(jq -n "${i}" | jq -r .endDateTime)
        KEYID=$(jq -n "${i}" | jq -r .keyId)
        compareDate $EXPIRES
    done < <(printf "%s" "${i}" | jq -c '.passwordCredentials[]')
}

function compareDate() {
    TODAY=$(date +%s)
    EXPIRES=$(date +%s -d "$1")
    DIFFERANSE=$((("$EXPIRES" - "$TODAY") / 86400))
    if [ "$DIFFERANSE" -le $RED_WARNING_DAYS ]; then
        printf "${red}"
        if [[ ${SECRET_NAME} == null ]]; then
            printf "${fmt}" "   ${DISPLAYNAME}" "${KEYID}" "${DIFFERANSE}"
        else
            printf "${fmt}" "   ${DISPLAYNAME}" "${SECRET_NAME}" "${DIFFERANSE}"
        fi
        printf "${normal}"
    elif [ "$DIFFERANSE" -le $YELLOW_WARNING_DAYS ]; then
        printf "${yel}"
        if [[ ${SECRET_NAME} == null ]]; then
            printf "${fmt}" "   ${DISPLAYNAME}" "${KEYID}" "${DIFFERANSE}"
        else
            printf "${fmt}" "   ${DISPLAYNAME}" "${SECRET_NAME}" "${DIFFERANSE}"
        fi
        printf "${normal}"
    fi
}

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Check App registrations secrets will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AAD_APP_NAME                     : Azure App registrations"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -r -p "   Is this correct? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            echo ""
            echo "   Quitting..."
            exit 0
            ;;
        *) echo "   Please answer yes or no." ;;
        esac
    done
    echo ""
fi

#######################################################################################
### Start
###

AZAPP=$(az ad app list --show-mine --query "[].{appId: appId, displayName: displayName, passwordCredentials: passwordCredentials}" | jq 'sort_by(.displayName | ascii_downcase)')
printf "${fmt2}" "   Display Name" "Description/Id" "Expires in:"
check_applications
