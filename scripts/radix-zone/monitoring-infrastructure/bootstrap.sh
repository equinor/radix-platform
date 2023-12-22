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

# RADIX_ZONE_ENV=../radix_zone_dev.env ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start bootstrap of Monitoring infrastructure.. "

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}

printf "All is good."
echo ""

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

LIB_SERVICE_PRINCIPAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../service-principals-and-aad-apps/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
    echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_SERVICE_PRINCIPAL_PATH"
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh
source ./create-sp.sh

# Optional inputs

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

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Monitoring infrastructure will use the following configuration:"
echo -e ""
echo -e "   > WHAT:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e ""
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_GROUP_MONITORING     : $AZ_RESOURCE_GROUP_MONITORING"
echo -e "   -  KEYVAULT                         : $AZ_RESOURCE_MON_KEYVAULT"
echo -e "   -  AD DEV GROUP                     : $AZ_AD_DEV_GROUP"
echo -e "   -  AD OPS GROUP                     : $AZ_AD_OPS_GROUP"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -r -p "Is this correct? (Y/n) " yn
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
fi

function create_resource_groups() {
    echo "Creating resource group..."
    az group create \
        --location "${AZ_RADIX_ZONE_LOCATION}" \
        --name "${AZ_RESOURCE_GROUP_MONITORING}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --output none
}

function create_keyvault() {

    echo "Check if keyvault exists..."

    # TODO: Create a better check if the keyvault exist
    az keyvault show --name "${AZ_RESOURCE_MON_KEYVAULT}" --only-show-errors --resource-group "${AZ_RESOURCE_GROUP_MONITORING}" || {
      echo "Missing, creating new key vault: ${AZ_RESOURCE_MON_KEYVAULT}..."
      az keyvault create \
          --name "${AZ_RESOURCE_MON_KEYVAULT}" \
          --resource-group "${AZ_RESOURCE_GROUP_MONITORING}" \
          --subscription "${AZ_SUBSCRIPTION_ID}" \
          --enable-purge-protection \
          --only-show-errors || {
          echo -e "\nERROR: Failed to create keyvault. Exiting... " >&2
          exit 1
      }
      echo "...Done"
    }

    echo "Set access policy for group Radix Platform Operators in key vault: ${AZ_RESOURCE_MON_KEYVAULT}..."
    az keyvault set-policy \
        --object-id "$(az ad group show --group "${AZ_AD_OPS_GROUP}" --query id --output tsv --only-show-errors)" \
        --name "${AZ_RESOURCE_MON_KEYVAULT}" \
        --resource-group "${AZ_RESOURCE_GROUP_MONITORING}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --certificate-permissions get list update create import delete recover backup restore managecontacts manageissuers getissuers listissuers setissuers deleteissuers \
        --key-permissions get list update create import delete recover backup restore \
        --secret-permissions get list set delete recover backup restore \
        --storage-permissions
    echo "...Done"

    echo "Set access policy for group Radix Platform Developers in key vault: ${AZ_RESOURCE_MON_KEYVAULT}..."
    az keyvault set-policy \
        --object-id "$(az ad group show --group "${AZ_AD_DEV_GROUP}" --query id --output tsv --only-show-errors)" \
        --name "${AZ_RESOURCE_MON_KEYVAULT}" \
        --resource-group "${AZ_RESOURCE_GROUP_MONITORING}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --certificate-permissions get list \
        --key-permissions get list \
        --secret-permissions get list \
        --storage-permissions \
        --only-show-errors
    echo "...Done"
}

create_resource_groups
create_keyvault
create_monitoring_service_principal "$APP_REGISTRATION_MONITORING" "Grafana Azure integration"
create_monitoring_ar_secret "$APP_REGISTRATION_MONITORING" "radix-grafana-azure" "Grafana Azure secret"
create_monitoring_service_principal "$APP_REGISTRATION_GRAFANA" "Grafana Oauth, main app for user authentication to Grafana"
create_monitoring_ar_secret "$APP_REGISTRATION_GRAFANA" "$APP_REGISTRATION_GRAFANA" "Grafana OAuth secret"

echo ""
echo "Bootstrap done!"
