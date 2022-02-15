#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# - Update the client secret for the "radix-velero-{dev|prod}" app registration 
# - Update the keyvault secret with the new client secret in the keyvault
# - Keyvault will be read from the provided RADIX_ZONE_ENV

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV : Path to *.env file

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./update_ar_client_secret.sh

#######################################################################################
### START
###

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Get velero env vars

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/velero.env"

# Local variables

SECRET_NAME=$AZ_VELERO_SERVICE_PRINCIPAL_NAME
APP_REGISTRATION_NAME=$AZ_VELERO_SERVICE_PRINCIPAL_NAME

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
echo -e "Update auth secret will use the following configuration:"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  SECRET_NAME                      : $SECRET_NAME"
echo -e "   -  APP_REGISTRATION_NAME            : $APP_REGISTRATION_NAME"
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
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

echo ""

# Get the existing secret
EXISTING_SECRET_VALUES_FILE="existing_secret_values.json"
test -f "$EXISTING_SECRET_VALUES_FILE" && rm "$EXISTING_SECRET_VALUES_FILE"
printf "Getting secret from keyvault \"$AZ_RESOURCE_KEYVAULT\"..."
if [[ ""$(az keyvault secret download --name "$SECRET_NAME" --vault-name "$AZ_RESOURCE_KEYVAULT" --file "$EXISTING_SECRET_VALUES_FILE" 2>&1)"" == *"ERROR"* ]]; then
    echo -e "\nERROR: Could not get secret \"$SECRET_NAME\" in keyvault \"$AZ_RESOURCE_KEYVAULT\". Exiting..."
    exit 1
fi
printf " Done.\n"

# Generate new secret for App Registration.
printf "Re-generate client secret for App Registration \"$APP_REGISTRATION_NAME\"..."
APP_REGISTRATION_CLIENT_ID=$(az ad app list --display-name "$APP_REGISTRATION_NAME" | jq -r '.[].appId')

UPDATED_CLIENT_SECRET=$(az ad app credential reset --id "$APP_REGISTRATION_CLIENT_ID" --credential-description "rbac" 2>/dev/null | jq -r '.password')
if [[ -z "$UPDATED_CLIENT_SECRET" ]]; then
    echo -e "\nERROR: Could not re-generate client secret for App Registration \"$APP_REGISTRATION_NAME\". Exiting..."
    exit 1
fi
printf " Done.\n"

# Get expiration date of updated credential
EXPIRATION_DATE=$(az ad app credential list --id $APP_REGISTRATION_CLIENT_ID --query "[?customKeyIdentifier=='rbac'].endDate" --output tsv | sed 's/\..*//')"Z"

# Create new .json file with updated credential.
UPDATED_SECRET_VALUES_FILE="updated_secret_values.json"
test -f "$UPDATED_SECRET_VALUES_FILE" && rm "$UPDATED_SECRET_VALUES_FILE"
echo $(jq '.password = "'${UPDATED_CLIENT_SECRET}'"' ${EXISTING_SECRET_VALUES_FILE}) | jq '.' >> $UPDATED_SECRET_VALUES_FILE

printf "Updating keyvault \"$AZ_RESOURCE_KEYVAULT\"..."
if [[ ""$(az keyvault secret set --name "$SECRET_NAME" --vault-name "$AZ_RESOURCE_KEYVAULT" --file "$UPDATED_SECRET_VALUES_FILE" --expires "$EXPIRATION_DATE" 2>&1)"" == *"ERROR"* ]]; then
    echo -e "\nERROR: Could not update secret in keyvault \"$AZ_RESOURCE_KEYVAULT\". Exiting..."
    exit 1
fi
printf " Done\n"

# Remove temporary files.
rm $EXISTING_SECRET_VALUES_FILE
rm $UPDATED_SECRET_VALUES_FILE

echo "Script completed successfully."
