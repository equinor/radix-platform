#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Update the client secret for servicenow client app registration and store in keyvault.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

#######################################################################################
### HOW TO USE
###

# Example 1:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env ./refresh_servicenow_proxy_client_app_credentials.sh

# Example 2: Using a subshell to avoid polluting parent shell
# (RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env ./refresh_servicenow_proxy_client_app_credentials.sh)

#######################################################################################
### START
###

echo ""
echo "Updating secret for the servicenow client app registration"

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}
printf "All is good."
echo ""

#######################################################################################
### Set default values for optional input
###

USER_PROMPT=${USER_PROMPT:=true}

# Validate mandatory input

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
echo -e "Update secret for the servicenow client app registration will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  KEYVAULT_SECRET                  : $KV_SECRET_SERVICENOW_CLIENT_SECRET"
echo -e "   -  APP_REGISTRATION_NAME            : $APP_REGISTRATION_SERVICENOW_CLIENT"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
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

function resetAppRegistrationPassword() {
    # Generate new secret for App Registration.
    printf "Re-generate client secret for App Registration \"$APP_REGISTRATION_SERVICENOW_CLIENT\"...\n"
    APP_REGISTRATION_CLIENT_ID=$(az ad app list --display-name "$APP_REGISTRATION_SERVICENOW_CLIENT" | jq -r '.[].appId')
    if [ -z "$APP_REGISTRATION_CLIENT_ID" ]; then
        echo -e "\nERROR: Could not find app registration \"$APP_REGISTRATION_SERVICENOW_CLIENT\"." >&2; 
        return 1;
    fi
    displayName=${RADIX_ZONE}-${RADIX_ENVIRONMENT}
    password=$(az ad app credential reset \
        --id "$APP_REGISTRATION_CLIENT_ID" \
        --display-name "$displayName" \
        --append \
        --query password \
        --output tsv \
        --only-show-errors) || { 
        echo -e "\nERROR: Could not re-generate client secret for App Registration \"$APP_REGISTRATION_SERVICENOW_CLIENT\"." >&2
        return 1
    }
    expiration_date="$(az ad app credential list --id "${APP_REGISTRATION_CLIENT_ID}" --query "sort_by([?displayName=='$displayName'], &endDateTime)[-1:].{endDateTime:endDateTime,keyId:keyId}" | jq -r .[].endDateTime | sed 's/\..*//')" || return
    az keyvault secret set --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${KV_SECRET_SERVICENOW_CLIENT_SECRET}" --value "${password}" --expires "${expiration_date}" --output none || return
    
    printf " Done.\n"
}

### MAIN
resetAppRegistrationPassword
