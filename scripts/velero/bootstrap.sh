#!/bin/bash

# PURPOSE
#
# Provision all az resources required to be able to use Velero in a radix cluster.
#
# Velero require az role Contributor for the resource group that contains the storage.
# Due to that requirement and because we do not want to run the risk of anything else touching the backups,
# we will set everything up in a new resource group dedicated to velero.

# USAGE
#
# AZ_INFRASTRUCTURE_ENVIRONMENT=dev ./bootstrap.sh

# KNOWN ISSUES
#
# You have to manually add owners to the service principal.
# See https://github.com/Azure/azure-cli/issues/9250

# INPUTS:
#
# AZ_INFRASTRUCTURE_ENVIRONMENT  (Mandatory. Example: prod|dev)


#######################################################################################
### START
### 

echo "Bootstrap Velero infrastructure..."


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

if [[ -z "$AZ_INFRASTRUCTURE_ENVIRONMENT" ]]; then
    echo -e "\nError: Please provide INFRASTRUCTURE_ENVIRONMENT. Value must be one of: \"prod\", \"dev\", \"test\"." >&2
    exit 1
fi

case "$AZ_INFRASTRUCTURE_ENVIRONMENT" in
    "prod" | "dev" | "test")
        # We got a valid value, lets override base env var
        AZ_INFRASTRUCTURE_ENVIRONMENT="$AZ_INFRASTRUCTURE_ENVIRONMENT"
        ;;
    *)
        echo ""
        echo "Error: INFRASTRUCTURE_ENVIRONMENT has an invalid value ($AZ_INFRASTRUCTURE_ENVIRONMENT).\nValue must be one of: \"prod\", \"dev\", \"test\"." >&2
        exit 1
esac


#######################################################################################
### CONFIGS
###

# Get velero env vars
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/velero.env"
# Get base radix env var
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../${AZ_INFRASTRUCTURE_ENVIRONMENT}.env"


#######################################################################################
### Prepare az session
###

echo ""
echo "Logging you in to Azure if not already logged in..."
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION" >/dev/null
printf "Done."
echo ""


#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Start provision of velero resources using the following settings:"
echo -e ""
echo -e "AZ_VELERO_RESOURCE_GROUP        : $AZ_VELERO_RESOURCE_GROUP"
echo -e "AZ_VELERO_STORAGE_ACCOUNT_ID    : $AZ_VELERO_STORAGE_ACCOUNT_ID"
echo -e "AZ_VELERO_SERVICE_PRINCIPAL_NAME: $AZ_VELERO_SERVICE_PRINCIPAL_NAME"
echo -e "INFRASTRUCTURE_ENVIRONMENT      : $AZ_INFRASTRUCTURE_ENVIRONMENT"
echo -e "AZ_SUBSCRIPTION                 : $AZ_SUBSCRIPTION"
echo -e "AZ_USER                         : $(az account show --query user.name -o tsv)"
echo -e ""

read -p "Is this correct? (Y/n) " -n 1 -r
if [[ "$REPLY" =~ (N|n) ]]; then
   echo ""
   echo "Quitting."
   exit 0
fi
echo ""


#######################################################################################
### Resource group and storage container
### 

echo ""
echo "Create resource group..."
az group create -n "$AZ_VELERO_RESOURCE_GROUP" --location "$AZ_INFRASTRUCTURE_REGION" 2>&1 >/dev/null
echo "Done."

echo ""
echo "Create storage account..."
az storage account create --name "$AZ_VELERO_STORAGE_ACCOUNT_ID" \
    --resource-group "$AZ_VELERO_RESOURCE_GROUP" \
    --sku Standard_GRS \
    --encryption-services blob \
    --https-only true \
    --kind BlobStorage \
    --access-tier Hot \
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

echo ""
echo "Create service principal..."
AZ_VELERO_SERVICE_PRINCIPAL_SCOPE="$(az group show --name ${AZ_VELERO_RESOURCE_GROUP} | jq -r '.id')"
AZ_VELERO_SERVICE_PRINCIPAL_PASSWORD="$(az ad sp create-for-rbac --name "$AZ_VELERO_SERVICE_PRINCIPAL_NAME" --scope="${AZ_VELERO_SERVICE_PRINCIPAL_SCOPE}" --role "Contributor" --query 'password' -o tsv)"
AZ_VELERO_SERVICE_PRINCIPAL_ID="$(az ad sp list --display-name "$AZ_VELERO_SERVICE_PRINCIPAL_NAME" --query '[0].appId' -o tsv)"
echo "Done."

echo ""
echo "Upload velero credentials to keyvault..."

AZ_VELERO_SECRET_PAYLOAD="$(cat << END
AZURE_SUBSCRIPTION_ID=$(az account list --query '[?isDefault].id' -o tsv)
AZURE_TENANT_ID=$(az account list --query '[?isDefault].tenantId' -o tsv)
AZURE_CLIENT_ID=${AZ_VELERO_SERVICE_PRINCIPAL_ID}
AZURE_CLIENT_SECRET=${AZ_VELERO_SERVICE_PRINCIPAL_PASSWORD}
AZURE_RESOURCE_GROUP=${AZ_VELERO_RESOURCE_GROUP}
END
)"

az keyvault secret set \
    --vault-name "$AZ_RESOURCE_KEYVAULT" \
    --name "$AZ_VELERO_SECRET_NAME" \
    --value "$AZ_VELERO_SECRET_PAYLOAD" \
    2>&1 >/dev/null

unset AZ_VELERO_SECRET_PAYLOAD # Clear credentials from memory
echo "Done."


#######################################################################################
### END
### 

echo ""
echo "WARNING!"
echo "You _must_ manually set team members as owners for the service principal \"$AZ_VELERO_SERVICE_PRINCIPAL_NAME\","
echo "as this is not possible to do by script (yet)."
echo ""

echo ""
echo "All done!"

