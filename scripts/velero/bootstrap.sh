#!/usr/bin/env bash


#######################################################################################
### PURPOSE
### 

# Provision all az resources required to be able to use Velero in a radix cluster.

# Velero require az role Contributor for the resource group that contains the storage.
# Due to that requirement and because we do not want to run the risk of anything else touching the backups,
# we will set everything up in a new resource group dedicated to velero.


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

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap.sh


#######################################################################################
### KNOWN ISSUES
### 

# You have to manually add owners to the service principal.
# See https://github.com/Azure/azure-cli/issues/9250



#######################################################################################
### START
### 

echo "Bootstrap Velero infrastructure..."


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2;  exit 1; }
printf "Done."
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

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Load dependencies
LIB_SERVICE_PRINCIPAL_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../service-principals-and-aad-apps/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
   echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
   exit 1
else
   source "$LIB_SERVICE_PRINCIPAL_PATH"
fi


#######################################################################################
### Prepare az session
###

echo ""
printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done."
echo ""

exit_if_user_does_not_have_required_ad_role


#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Bootstrap Velero will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_VELERO_RESOURCE_GROUP         : $AZ_VELERO_RESOURCE_GROUP"
echo -e "   -  AZ_VELERO_STORAGE_ACCOUNT_ID     : $AZ_VELERO_STORAGE_ACCOUNT_ID"
echo -e "   -  APP_REGISTRATION_VELERO          : $APP_REGISTRATION_VELERO"
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

#######################################################################################
### Resource group and storage container
### 

echo ""
echo "Create resource group..."
az group create -n "$AZ_VELERO_RESOURCE_GROUP" --location "$AZ_RADIX_ZONE_LOCATION" 2>&1 >/dev/null
echo "Done."

echo ""
echo "Create storage account..."
az storage account create --name "$AZ_VELERO_STORAGE_ACCOUNT_ID" \
    --resource-group "$AZ_VELERO_RESOURCE_GROUP" \
    --encryption-services blob \
    --https-only true \
    --access-tier Hot \
    --min-tls-version "${AZ_STORAGEACCOUNT_MIN_TLS_VERSION}" \
    --sku "${AZ_STORAGEACCOUNT_SKU}" \
    --kind "${AZ_VELERO_STORAGE_ACCOUNT_KIND}" \
    --access-tier "${AZ_STORAGEACCOUNT_TIER}"
    2>&1 >/dev/null
echo "Done."

# The blob has to be unique for each cluster, and so we will create a blob when installing the base components for the cluster.
# This blob will be shared among all clusters. Not good.
# We will move the creation of a separate blob per cluster into the "install base components" script.
# echo ""
# echo "Create storage container..."
# az storage container create -n "$AZ_VELERO_STORAGE_BLOB_CONTAINER" \
#     --public-access off \
#     --account-name "$AZ_VELERO_STORAGE_ACCOUNT_ID" \
#     2>&1 >/dev/null
# echo "Done."


#######################################################################################
### Service principal
###


printf "Working on \"${APP_REGISTRATION_VELERO}\": Creating service principal..."
AZ_VELERO_SERVICE_PRINCIPAL_SCOPE="$(az group show --name ${AZ_VELERO_RESOURCE_GROUP} | jq -r '.id')"
AZ_VELERO_SERVICE_PRINCIPAL_PASSWORD="$(az ad sp create-for-rbac --name "$APP_REGISTRATION_VELERO" --scope="${AZ_VELERO_SERVICE_PRINCIPAL_SCOPE}" --role "Contributor" --query 'password' -o tsv)"
AZ_VELERO_SERVICE_PRINCIPAL_ID="$(az ad sp list --display-name "$APP_REGISTRATION_VELERO" --query '[0].appId' -o tsv)"
AZ_VELERO_SERVICE_PRINCIPAL_DESCRIPTION="Used by Velero to access Azure resources"

printf "Update credentials in keyvault..."
update_service_principal_credentials_in_az_keyvault "${APP_REGISTRATION_VELERO}" "${AZ_VELERO_SERVICE_PRINCIPAL_ID}" "${AZ_VELERO_SERVICE_PRINCIPAL_PASSWORD}" "${AZ_VELERO_SERVICE_PRINCIPAL_DESCRIPTION}"
printf "Done.\n"

# Clean up
unset AZ_VELERO_SERVICE_PRINCIPAL_PASSWORD # Clear credentials from memory

echo ""
echo "WARNING!"
echo "You _must_ manually set team members as owners for the service principal \"$APP_REGISTRATION_VELERO\","
echo "as this is not possible to do by script (yet)."
echo ""

echo ""
echo "Bootstrap of Velero is done!"

