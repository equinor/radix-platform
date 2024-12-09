#!/usr/bin/env bash

#######################################################################################
### HOW TO USE
# sh ./update_auth_secret.sh env

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

APP_REGISTRATION="radix-cicd-canary-private-acr"
APP_SECRET_NAME="radix-cicd-canary-values-$1"
SECRETNAME="radix-cicd-canary-values"
KEYVAULT="radix-keyv-$1"

#######################################################################################

cat << EOF
Will use the following configuration:

    -------------------------------------------------------------------
    -  APP Registration    : $APP_REGISTRATION
    -  Key Vault           : $KEYVAULT
    -  Secret              : $SECRETNAME
    -  App secret name     : $APP_SECRET_NAME
    -------------------------------------------------------------------
    -  AZ subscription     : $(az account show --query name -otsv)
    -  AZ user             : $(az account show --query user.name -o tsv)
EOF

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

echo "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null

echo "Generating new client secret for App Registration $APP_REGISTRATION..."
id=$(az ad app list --filter "displayname eq '${APP_REGISTRATION}'" | jq -r '.[].appId')
password="$(az ad app credential reset --id "${id}" --display-name "${APP_SECRET_NAME}" --append --query password --output tsv --only-show-errors)"
expiration_date="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='${APP_SECRET_NAME}'], &endDateTime)[-1].endDateTime" --output tsv)"


echo "Getting secret $SECRETNAME from keyvault $KEYVAULT..."
SECRET_VALUES=$(az keyvault secret show \
    --vault-name "$KEYVAULT" \
    --name "$SECRETNAME" 2>/dev/null |
    jq --arg password "${password}" \
    '.value | fromjson | .privateImageHub.password=$password')

if [[ -z "$SECRET_VALUES" ]]; then
    echo -e "\nERROR: Could not get secret from keyvault $KEYVAULT. Exiting..." >&2
    exit 1
fi

echo "Updating secret $SECRETNAME in keyvault $KEYVAULT..."
az keyvault secret set --vault-name "$KEYVAULT" --name "$SECRETNAME" --value "$SECRET_VALUES" --expires "$EXPIRATION_DATE" --output none || exit

echo "Client secret refreshed and stored in Keyvault: $KEYVAULT"

