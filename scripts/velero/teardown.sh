#!/bin/bash

#######################################################################################
### PURPOSE
### 

# Remove all infrastructure in a given az subscription that is related to Velero.
# ...Basically an "undo" for what ever the velero bootstrap script did.


#######################################################################################
### USAGE
### 

# INFRASTRUCTURE_ENVIRONMENT=dev ./teardown.sh



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
### Validate mandatory input
###

if [[ -z "$INFRASTRUCTURE_ENVIRONMENT" ]]; then
   echo ""
   echo "Error: Please provide INFRASTRUCTURE_ENVIRONMENT. Value must be one of: \"prod\", \"dev\"." >&2
   exit 1
fi

case "$INFRASTRUCTURE_ENVIRONMENT" in
   "prod" | "dev")
        # We got a valid value, lets override base env var
        RADIX_ENVIRONMENT="$INFRASTRUCTURE_ENVIRONMENT"
      ;;
   *)
      echo ""
      echo "Error: INFRASTRUCTURE_ENVIRONMENT has an invalid value ($INFRASTRUCTURE_ENVIRONMENT).\nValue must be one of: \"prod\", \"dev\"." >&2
      exit 1
esac


#######################################################################################
### CONFIGS
###

# Get velero env vars
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/velero.env"
# Get base radix env var
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../${INFRASTRUCTURE_ENVIRONMENT}.env"


#######################################################################################
### Prepare az session
###

echo ""
echo "Logging you in to Azure if not already logged in..."
az account show > /dev/null || az login > /dev/null
az account set --subscription "$AZ_SUBSCRIPTION" > /dev/null
printf "Done."
echo ""


#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Remove velero resources using the following settings:"
echo -e ""
echo -e "AZ_VELERO_RESOURCE_GROUP    : $AZ_VELERO_RESOURCE_GROUP"
echo -e "AZ_VELERO_STORAGE_ACCOUNT_ID: $AZ_VELERO_STORAGE_ACCOUNT_ID"
echo -e "INFRASTRUCTURE_ENVIRONMENT  : $RADIX_ENVIRONMENT"
echo -e "AZ_SUBSCRIPTION             : $AZ_SUBSCRIPTION"
echo -e "AZ_USER                     : $(az account show --query user.name -o tsv)"
echo -e ""

read -p "Is this correct? (Y/n) " -n 1 -r
if [[ "$REPLY" =~ (N|n) ]]; then
   echo ""
   echo "Quitting."
   exit 0
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
[ "$AZ_VELERO_SERVICE_PRINCIPAL_NAME" != "http://"* ] && { AZ_VELERO_SERVICE_PRINCIPAL_NAME="http://${AZ_VELERO_SERVICE_PRINCIPAL_NAME}"; }
az ad sp delete --id "$AZ_VELERO_SERVICE_PRINCIPAL_NAME" 2>&1 >/dev/null
echo "Done."

echo ""
echo "Deleting service principal credentials..."
az keyvault secret delete --vault-name "$AZ_RESOURCE_KEYVAULT" -n "$AZ_VELERO_SECRET_NAME" 2>&1 >/dev/null
echo "Done."


#######################################################################################
### END
### 

echo ""
echo "All done!"