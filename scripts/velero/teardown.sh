#!/bin/bash

#######################################################################################
### PURPOSE
### 

# Remove all infrastructure in a given az subscription that is related to Velero.
# ...Basically an "undo" for what ever the velero bootstrap script did.


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

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./teardown.sh


#######################################################################################
### START
### 

echo "Start Velero teardown..."


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting..." >&2;  exit 1; }
printf "Done."
echo ""


#######################################################################################
### Read inputs and configs
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

# Load dependencies
LIB_SERVICE_PRINCIPAL_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../service-principals-and-aad-apps/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
   echo "The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
   exit 1
else
   source "$LIB_SERVICE_PRINCIPAL_PATH"
fi


#######################################################################################
### Prepare az session
###

echo ""
echo "Logging you in to Azure if not already logged in..."
az account show > /dev/null || az login > /dev/null
az account set --subscription "$AZ_SUBSCRIPTION" > /dev/null
printf "Done."
echo ""

exit_if_user_does_not_have_required_ad_role


#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Tear down of Velero will use the following configuration:"
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
echo -e "   -  AZ_VELERO_SERVICE_PRINCIPAL_NAME : $AZ_VELERO_SERVICE_PRINCIPAL_NAME"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $AZ_SUBSCRIPTION"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    read -p "Is this correct? (Y/n) " -n 1 -r
    if [[ "$REPLY" =~ (N|n) ]]; then
    echo ""
    echo "Quitting."
    exit 0
    fi
    echo ""
fi

echo ""


#######################################################################################
### DESTROY!1
###

# We need to delete the storage account first due to azure weirdness.
# Normally we would just delete the RG and that would also delete everything inside of it,
# but it turns out that azure does not handle deletion of storage accounts properly when doing so.
echo ""
echo "Deleting storage account..."
az storage account delete --yes -g "$AZ_VELERO_RESOURCE_GROUP" -n "$AZ_VELERO_STORAGE_ACCOUNT_ID" 2>&1 >/dev/null
echo "Done."

echo ""
echo "Deleting resource group..."
az group delete --yes --name "$AZ_VELERO_RESOURCE_GROUP" 2>&1 >/dev/null
echo "Done."

echo ""
echo "Deleting service principal..."
# More az weirdness, az sp name require "http://"...
AZ_SP_WEIRD_NAME="$AZ_VELERO_SERVICE_PRINCIPAL_NAME"
[ "$AZ_SP_WEIRD_NAME" != "http://"* ] && { AZ_SP_WEIRD_NAME="http://${AZ_VELERO_SERVICE_PRINCIPAL_NAME}"; }
az ad sp delete --id "$AZ_SP_WEIRD_NAME" 2>&1 >/dev/null
echo "Done."

echo ""
echo "Deleting service principal credentials..."
az keyvault secret delete --vault-name "$AZ_RESOURCE_KEYVAULT" -n "$AZ_VELERO_SERVICE_PRINCIPAL_NAME" 2>&1 >/dev/null
echo "Done."


#######################################################################################
### END
### 

echo ""
echo "All done!"