#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# - Update the client secret for the "radix-cicd-canary-private-acr" app registration 
# - Update the keyvault secret with the new client secret in multiple keyvaults


#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE          : dev|playground|prod|c2|c3

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE=dev ./update_auth_secret.sh

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2|c3)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2|c3" >&2
    exit 1
fi

# Optional inputs

USER_PROMPT=${USER_PROMPT:=true}

# Source util scripts
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

# Local variables

SECRET_NAME="radix-cicd-canary-values"
APP_REGISTRATION_NAME="radix-cicd-canary-private-acr"
APP_SECRET_NAME="$RADIX_ZONE"

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
echo -e "   -  KV_SECRET_NAME                   : $SECRET_NAME"
echo -e "   -  APP_REGISTRATION_NAME            : $APP_REGISTRATION_NAME"
echo -e "   -  APP_SECRET_NAME                  : $APP_SECRET_NAME"
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
APP_REGISTRATION_CLIENT_ID=$(az ad app list --filter "displayname eq '${APP_REGISTRATION_NAME}'" | jq -r '.[].appId')

UPDATED_PRIVATE_IMAGE_HUB_PASSWORD=$(az ad app credential reset --id "$APP_REGISTRATION_CLIENT_ID" --append --display-name "$APP_SECRET_NAME" 2>/dev/null | jq -r '.password')
if [[ -z "$UPDATED_PRIVATE_IMAGE_HUB_PASSWORD" ]]; then
    echo -e "\nERROR: Could not re-generate client secret for App Registration \"$APP_REGISTRATION_NAME\". Exiting..." >&2
    exit 1
fi
printf " Done.\n"

# Get expiration date of updated credential
EXPIRATION_DATE=$(az ad app credential list --id $APP_REGISTRATION_CLIENT_ID --query "sort_by([?displayName=='${APP_SECRET_NAME}'], &endDateTime)[-1].endDateTime" --output tsv | sed 's/\..*//')""

printf "Getting secret from keyvault \"$AZ_RESOURCE_KEYVAULT\"..."
SECRET_VALUES=$(az keyvault secret show \
    --vault-name "$AZ_RESOURCE_KEYVAULT" \
    --name radix-cicd-canary-values 2>/dev/null |
    jq --arg password "${UPDATED_PRIVATE_IMAGE_HUB_PASSWORD}" \
    '.value | fromjson | .privateImageHub.password=$password')

if [[ -z "$SECRET_VALUES" ]]; then
    echo -e "\nERROR: Could not get secret \"$SECRET_NAME\" in keyvault \"$AZ_RESOURCE_KEYVAULT\". Exiting..." >&2
    exit 1
fi
printf " Done.\n"

# Update keyvault with new json secret
printf "Updating keyvault \"$AZ_RESOURCE_KEYVAULT\"..."

az keyvault secret set --name "$SECRET_NAME" --vault-name "$AZ_RESOURCE_KEYVAULT" --value "$SECRET_VALUES" --expires "$EXPIRATION_DATE" --output none || exit

printf " Done\n"

