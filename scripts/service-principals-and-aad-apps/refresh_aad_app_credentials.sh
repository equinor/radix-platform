#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Refresh credentials for radix service principals in
# - Azure AD
# - Radix Zone key vault
# - Cluster?

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - AAD_APP_NAME        : Name of aad app, example: "radix-rbac-dev"
# - SECRET              : Name of the secret in Keyvault

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env AAD_APP_NAME=demo-rbac-dev ./refresh_aad_app_credentials.sh
# This makes the JSON look like
# {
#   "name": "",
#   "id": "",
#   "password": "",
#   "description": "",
#   "tenantId": "",
#   "secretId": ""
# }


#######################################################################################
### START
###

echo ""
echo "Start refreshing credentials for radix aad app... "

#######################################################################################
### Check for prerequisites binaries
###

printf "Check for neccesary executables for \"$(basename ${BASH_SOURCE[0]})\"... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting... " >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}
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

if [[ -z "$AAD_APP_NAME" ]]; then
    echo "ERROR: Please provide SP_NAME" >&2
    exit 1
fi

if [[ -z "$SECRET" ]]; then
    echo "ERROR: Please provide SECRET" >&2
    exit 1
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Load dependencies
LIB_SERVICE_PRINCIPAL_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
    echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_SERVICE_PRINCIPAL_PATH"
fi

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
echo -e "Refresh credentials for radix ad apps will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                               : $RADIX_ZONE"
echo -e "   -  AZ_RESOURCE_KEYVAULT                     : $AZ_RESOURCE_KEYVAULT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AAD_APP_NAME                             : $AAD_APP_NAME"
echo -e "   -  SECRET                                   : $SECRET"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                          : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                                  : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Is this correct? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            echo ""
            echo "Quitting."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    echo ""
fi

#######################################################################################
### Refresh credentials in Azure AD and key vault
###

refresh_ad_app_and_store_credentials_in_ad_and_keyvault "$AAD_APP_NAME" "$SECRET"

#######################################################################################
### Explain manual steps
###

echo ""
echo ">> You must manually update credentials in the clusters."
echo ">> See README for which workflow to use depending on use case."

#######################################################################################
### END
###
