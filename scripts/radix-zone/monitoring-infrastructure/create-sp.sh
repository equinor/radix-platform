#!/usr/bin/env bash

#######################################################################################
### PURPOSE
### 

# Bootstrap radix zone infrastructure for monitoring, resource gorups, keyvault etc


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

# sh ./create-sp.sh 'env'

echo "Start bootstrap of Monitoring infrastructure.. "

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
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"




cat << EOF
Will use the following configuration:
    ------------------------------------------------------------------
    -  RADIX_ZONE                       : $RADIX_ZONE
    -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION
    -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT
    -  APP_REGISTRATION_GRAFANA         : $APP_REGISTRATION_GRAFANA

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

function create_monitoring_service_principal() {

    local name          # Input 1
    local description   # Input 2, optional
    local password
    local id

    name="$1"
    description="$2"

    echo "Working on ${name}: Creating service principal..."

    # Skip creation if the sp exist
    local testSP
    testSP="$(az ad sp list --display-name "${name}" --query [].id --output tsv 2> /dev/null)"
    if [ -z "$testSP" ]; then
        echo "creating ${name}..."
        password="$(az ad sp create-for-rbac --name "${name}" --query password --output tsv)"
        id="$(az ad sp list --display-name "${name}" --query [].id --output tsv)"
        secret="$(az ad sp credential list --id "${id}" --query "sort_by([?displayName=='rbac'], &endDateTime)[-1:].{endDateTime:endDateTime,keyId:keyId}")"
        secret_id="$(echo "${secret}" | jq -r .[].keyId)"
        expiration_date="$(echo "${secret}" | jq -r .[].endDateTime | sed 's/\..*//')"
        echo " Done.\n"

        echo "Update credentials in keyvault..."
        update_app_credentials_in_az_keyvault "${name}" "${id}" "${password}" "${description}" "${secret_id}" "${expiration_date}" "${AZ_RESOURCE_MON_KEYVAULT}"
    else
        echo "${name} exists.\n"
    fi

    echo "Update owners of app registration..."
    update_ad_app_owners "${name}"

    echo "Update owners of service principal..."
    update_service_principal_owners "${name}"

    echo "Update additional SP info..."
        id="$(az ad sp list --display-name "${name}" --query [].id --output tsv)"
        echo "This id ${id} and description: ${description}"
        az ad sp update --id "${id}" --set notes="${description}"

    echo "Done.\n"
}

function create_grafana_azure_secret(){    
    local name          # Input 1
    local secretname    # Input 2
    local description   # Input 3, optional


    name="$1"
    secretname="$2"
    description="$3"
 
    echo "Create secret for ${name}"
    id="$(az ad app list --display-name "${name}" --query [].id --output tsv)"
    
    password="$(az ad app credential reset --id "${id}" --display-name "${secretname}" --append --query password --output tsv --only-show-errors)"
    secret="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='${secretname}'], &endDateTime)[-1].{endDateTime:endDateTime,keyId:keyId}")"
    secret_id="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='${secretname}'], &endDateTime)[-1].keyId")"
    expiration_date="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='${secretname}'], &endDateTime)[-1].endDateTime" --output tsv)"
    
    echo "Update credentials in keyvault..."
    update_app_credentials_in_az_keyvault "${secretname}" "${id}" "${password}" "${description}" "${secret_id}" ${expiration_date} "${AZ_RESOURCE_MON_KEYVAULT}"
}


echo "Create Service Principal for Monitoring..."
create_monitoring_service_principal "$APP_REGISTRATION_GRAFANA" "Grafana OAuth"
create_grafana_azure_secret "$APP_REGISTRATION_GRAFANA" "radix-grafana-azure" "Grafana Azure secret"
echo "...Done."