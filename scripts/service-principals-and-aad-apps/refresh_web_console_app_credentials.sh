#!/usr/bin/env bash


#######################################################################################
### PURPOSE
### 

# Refresh credentials for Radix Web Console AAD app and store in keyvault

#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.


#######################################################################################
### HOW TO USE
### 

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./refresh_web_console_app_credentials.sh


#######################################################################################
### START
### 

echo ""
echo "Start refreshing credentials for Radix Web Console AAD app... "


#######################################################################################
### Check for prerequisites binaries
###

printf "Check for neccesary executables for \"$(basename ${BASH_SOURCE[0]})\"... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
hash jq 2> /dev/null || { echo -e "\nERROR: jq not found in PATH. Exiting... " >&2;  exit 1; }
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

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

WEB_CONSOLE_DISPLAY_NAME=$(az ad app show --id "${OAUTH2_PROXY_CLIENT_ID}" --query displayName --output tsv) || exit

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
echo -e "Refresh credentials for Radix Web Console will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                               : $RADIX_ZONE"
echo -e "   -  AZ_RESOURCE_KEYVAULT                     : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  VAULT_CLIENT_SECRET_NAME                 : $VAULT_CLIENT_SECRET_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  Radix Web Console App Name               : $WEB_CONSOLE_DISPLAY_NAME"
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
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    echo ""
fi

#######################################################################################
### Refresh credentials for Radix Web Console app in Azure AD and store in key vault
###

printf "Generating new app secret for ${WEB_CONSOLE_DISPLAY_NAME} in Azure AD..."

password="$(az ad app credential reset --id "${OAUTH2_PROXY_CLIENT_ID}" --display-name "web console" --append --query password --output tsv)"
secret="$(az ad app credential list --id "${OAUTH2_PROXY_CLIENT_ID}" --query "sort_by([?displayName=='web console'], &endDateTime)[-1:].{endDateTime:endDateTime,keyId:keyId}")"
expiration_date="$(echo "${secret}" | jq -r .[].endDateTime | sed 's/\..*//')" || exit

printf "Update credentials for ${WEB_CONSOLE_DISPLAY_NAME} in keyvault ${AZ_RESOURCE_KEYVAULT}..."

# Upload to keyvault
az keyvault secret set --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${VAULT_CLIENT_SECRET_NAME}" --value "${password}" --expires "${expiration_date}" --output none || exit

printf "Done.\n"


#######################################################################################
### Explain manual steps
###

echo ""
echo ">> You must update credentials for Radix Web Console in clusters."
echo ">> See Refresh Radix Web Console App Credentials in README."


#######################################################################################
### END
###