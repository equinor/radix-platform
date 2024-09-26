#!/usr/bin/env bash

# sh ./create-sp.sh 'env'

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
    KEYVAULT="radix-keyv-%1"
fi


cat << EOF
Will use the following configuration:

    -------------------------------------------------------------------
    -  APP REGISTRATION     : $APP_REGISTRATION
    -  KEYVAULT             : $KEYVAULT
    -------------------------------------------------------------------
    -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)
    -  AZ_USER                          : $(az account show --query user.name -o tsv)
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
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"



LIB_SERVICE_PRINCIPAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../service-principals-and-aad-apps/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
    echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_SERVICE_PRINCIPAL_PATH"
fi



name="$APP_REGISTRATION"
secretname="$name"
description="Grafana OAuth secret"

echo "Create secret for ${name}"
id="$(az ad app list --filter "displayname eq '${name}'" --query [].id --output tsv)"

password="$(az ad app credential reset --id "${id}" --display-name "${secretname}" --append --query password --output tsv --only-show-errors)"
secret="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='${secretname}'], &endDateTime)[-1].{endDateTime:endDateTime,keyId:keyId}")"
secret_id="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='${secretname}'], &endDateTime)[-1].keyId")"
expiration_date="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='${secretname}'], &endDateTime)[-1].endDateTime" --output tsv)"

echo "Update credentials in keyvault..."
    
update_app_credentials_in_az_keyvault "${secretname}" "${id}" "${password}" "${description}" "${secret_id}" ${expiration_date} "${KEYVAULT}"

echo "Client secret refreshed and stored in Keyvault"
