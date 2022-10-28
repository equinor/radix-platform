#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# - Update the client secret for the "radix-cicd-canary-private-acr" app registration 
# - Update the keyvault secret with the new client secret in multiple keyvaults
# - KEYVAULT_LIST is a comma-separated string of the keyvaults to update


#######################################################################################
### INPUTS
###

# Required:
# - KEYVAULT_LIST       : Comma-separated string of keyvaults to update: "keyvault-1,keyvault-2,keyvault-3"

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# KEYVAULT_LIST="radix-vault-dev,radix-vault-prod,radix-vault-c2-prod" ./update_auth_secret.sh


#######################################################################################
### START
###

# Required inputs

if [[ -z "$KEYVAULT_LIST" ]]; then
    echo "ERROR: Please provide KEYVAULT_LIST" >&2
    exit 1
fi

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Local variables

SECRET_NAME="radix-cicd-canary-values"
APP_REGISTRATION_NAME="radix-cicd-canary-private-acr"

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
echo -e "   -  KEYVAULT_LIST                    : $KEYVAULT_LIST"
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
    echo ""
fi

# Generate new secret for App Registration.
printf "Re-generate client secret for App Registration \"$APP_REGISTRATION_NAME\"..."
APP_REGISTRATION_CLIENT_ID=$(az ad app list --display-name "$APP_REGISTRATION_NAME" | jq -r '.[].appId')

UPDATED_PRIVATE_IMAGE_HUB_PASSWORD=$(az ad app credential reset --id "$APP_REGISTRATION_CLIENT_ID" --display-name "rdx-cicd-canary" 2>/dev/null | jq -r '.password')
if [[ -z "$UPDATED_PRIVATE_IMAGE_HUB_PASSWORD" ]]; then
    echo -e "\nERROR: Could not re-generate client secret for App Registration \"$APP_REGISTRATION_NAME\". Exiting..." >&2
    exit 1
fi
printf " Done.\n"

# Get expiration date of updated credential
EXPIRATION_DATE=$(az ad app credential list --id $APP_REGISTRATION_CLIENT_ID --query "[?displayName=='rdx-cicd-canary'].endDateTime" --output tsv | sed 's/\..*//')""
# Get the existing secret and change the value using jq.
FIRST_KEYVAULT=${KEYVAULT_LIST%%,*}

printf "Getting secret from keyvault \"$FIRST_KEYVAULT\"..."
SECRET_VALUES=$(az keyvault secret show \
    --vault-name "$FIRST_KEYVAULT" \
    --name radix-cicd-canary-values 2>/dev/null |
    jq --arg password "${UPDATED_PRIVATE_IMAGE_HUB_PASSWORD}" \
    '.value | fromjson | .privateImageHub.password=$password')

if [[ -z "$SECRET_VALUES" ]]; then
    echo -e "\nERROR: Could not get secret \"$SECRET_NAME\" in keyvault \"$FIRST_KEYVAULT\". Exiting..." >&2
    exit 1
fi
printf " Done.\n"

# Update keyvault with new json secret for every keyvault in KEYVAULT_LIST
oldIFS=$IFS
IFS=","
for KEYVAULT_NAME in $KEYVAULT_LIST; do
    printf "Updating keyvault \"$KEYVAULT_NAME\"..."
    if [[ ""$(az keyvault secret set --name "$SECRET_NAME" --vault-name "$KEYVAULT_NAME" --value "$SECRET_VALUES" --expires "$EXPIRATION_DATE" 2>&1)"" == *"ERROR"* ]]; then
        echo -e "\nERROR: Could not update secret in keyvault \"$KEYVAULT_NAME\"." >&2
        script_errors=true
        continue
    fi
    printf " Done\n"
done
IFS=$oldIFS

if [[ $script_errors == true ]]; then
    echo "ERROR: Script completed with errors." >&2
else
    echo "Script completed successfully."
fi
