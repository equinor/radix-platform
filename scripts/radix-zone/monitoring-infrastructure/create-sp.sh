#!/usr/bin/env bash

#######################################################################################
### HOW TO USE
### 

# sh ./create-sp.sh 'env'

echo "Create Grafana Service Principal "

RADIX_ZONE_ENV="../radix_zone_$1.env"
#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"


#######################################################################################
### Read inputs and configs
###


if [[ $1 == "ext-mon" ]]; then
    APP_REGISTRATION="radix-ar-grafana-ext-mon"
    KEYVAULT="radix-keyv-extmon"
else
    APP_REGISTRATION="radix-ar-grafana-$1"
    KEYVAULT="radix-keyv-$1"
fi

SECRETNAME="radix-ar-grafana-oauth"


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


#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
printf "Done.\n"


cat << EOF
Will use the following configuration:
    ------------------------------------------------------------------
    -  RADIX_ZONE                       : $RADIX_ZONE
    -  APP_REGISTRATION_GRAFANA         : $APP_REGISTRATION

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

LIB_SERVICE_PRINCIPAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../service-principals-and-aad-apps/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
    echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_SERVICE_PRINCIPAL_PATH"
fi


name=$APP_REGISTRATION
description="Grafana Oauth, main app for user authentication to Grafana"

# Skip creation if the sp exist

testSP="$(az ad sp list --display-name "${name}" --query [].id --output tsv 2>/dev/null)"
if [ -z "$testSP" ]; then
    echo "$testSP, ${name} does not exist"

    password="$(az ad sp create-for-rbac --name "${name}" --query password --output tsv)"
    id="$(az ad sp list --display-name "${name}" --query [].id --output tsv)"
    password="$(az ad sp credential reset --id "${id}" --display-name "${SECRETNAME}" --append --query password --output tsv --only-show-errors)"
    secret="$(az ad sp credential list --id "${id}" --query "sort_by([?displayName=='${SECRETNAME}'], &endDateTime)[-1:].{endDateTime:endDateTime,keyId:keyId}")"
    expiration_date="$(echo "${secret}" | jq -r .[].endDateTime | sed 's/\..*//')"
    
    echo "Update credentials in keyvault for appId $id, $secret with exp. date $expiration_date"
    az keyvault secret set --vault-name $KEYVAULT --name $SECRETNAME --value "${password}" --expires ${expiration_date} 2>&1 >/dev/null
else
    id=$testSP
    echo "${name} exists.\n"
fi

echo "Update additional info, $name - $description"
id="$(az ad sp list --display-name "${name}" --query [].id --output tsv)"

echo "Update description"
az ad sp update --id "${id}" --set notes="${description}"

echo "Update owners of app registration...."
update_ad_app_owners "${name}"

echo "Update owners of service principal..."
update_service_principal_owners "${name}"


echo "Done."



