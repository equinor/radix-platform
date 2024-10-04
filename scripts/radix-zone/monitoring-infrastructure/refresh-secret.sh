#!/usr/bin/env bash

# sh ./refresh-secret.sh 'env'

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"


if [[ $1 == "ext-mon" ]]; then
    APP_REGISTRATION="radix-ar-grafana-ext-mon"
    KEYVAULT="radix-keyv-extmon"
else
    APP_REGISTRATION="radix-ar-grafana-$1"
    KEYVAULT="radix-keyv-$1"
fi

SECRETNAME="radix-ar-grafana-oauth"

cat << EOF
Will use the following configuration:

    -------------------------------------------------------------------
    -  APP Registration    : $APP_REGISTRATION
    -  Key Vault           : $KEYVAULT
    -  Secret              : $SECRETNAME
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
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null

appname="$APP_REGISTRATION"


echo "Create secret for ${appname}"
id="$(az ad app list --filter "displayname eq '${appname}'" --query [].id --output tsv)"

password="$(az ad app credential reset --id "${id}" --display-name "${SECRETNAME}" --append --query password --output tsv --only-show-errors)"
expiration_date="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='${SECRETNAME}'], &endDateTime)[-1].endDateTime" --output tsv)"

# update_app_credentials_in_az_keyvault 
echo "Update credentials in keyvault..."

az keyvault secret set --vault-name $KEYVAULT --name $SECRETNAME --value "${password}" --expires ${expiration_date} 2>&1 >/dev/null

echo "Client secret refreshed and stored in Keyvault"
