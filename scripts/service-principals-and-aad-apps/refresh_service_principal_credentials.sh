#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Refresh credentials for radix service principals in
# - Azure AD
# - Radix Zone key vault

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE          : dev|playground|prod|c2
# - SP_NAME             : Name of service principal, example: "radix-something-dev"

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE=dev SP_NAME=demo-sp-dev ./refresh_service_principal_credentials.sh

#######################################################################################
### START
###

echo ""
echo "Start refreshing credentials for radix service principals... "

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

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2" >&2
    exit 1
fi

if [[ -z "$SP_NAME" ]]; then
    echo "ERROR: Please provide SP_NAME" >&2
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

RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

#######################################################################################
### Environment
###
printf "\n%s► Read YAML configfile $RADIX_ZONE"
RADIX_ZONE_ENV=$(config_path $RADIX_ZONE)
printf "\n%s► Read terraform variables and configuration"
RADIX_RESOURCE_JSON=$(environment_json $RADIX_ZONE)
RADIX_ZONE_YAML=$(cat <<EOF
$(<$RADIX_ZONE_ENV)
EOF
)
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_KEYVAULT=$(jq -r .keyvault <<< "$RADIX_RESOURCE_JSON")
#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

exit_if_user_does_not_have_required_ad_role

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Refresh credentials for radix service principals will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                               : $RADIX_ZONE"
echo -e "   -  AZ_RESOURCE_KEYVAULT                     : $AZ_RESOURCE_KEYVAULT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  SP_NAME                                  : $SP_NAME"
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

refresh_service_principal_and_store_credentials_in_ad_and_keyvault "$SP_NAME"

#######################################################################################
### Explain manual steps
###

echo ""
echo ">> You must manually update credentials in the clusters."
echo ">> See README for which workflow to use depending on use case."

#######################################################################################
### END
###
