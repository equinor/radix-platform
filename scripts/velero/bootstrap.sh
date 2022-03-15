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
echo -e "   -  AZ_VELERO_SERVICE_PRINCIPAL_NAME : $AZ_VELERO_SERVICE_PRINCIPAL_NAME"
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


printf "Working on \"${AZ_VELERO_SERVICE_PRINCIPAL_NAME}\": Creating service principal..."
AZ_VELERO_SERVICE_PRINCIPAL_SCOPE="$(az group show --name ${AZ_VELERO_RESOURCE_GROUP} | jq -r '.id')"
AZ_VELERO_SERVICE_PRINCIPAL_PASSWORD="$(az ad sp create-for-rbac --name "$AZ_VELERO_SERVICE_PRINCIPAL_NAME" --scope="${AZ_VELERO_SERVICE_PRINCIPAL_SCOPE}" --role "Contributor" --query 'password' -o tsv)"
AZ_VELERO_SERVICE_PRINCIPAL_ID="$(az ad sp list --display-name "$AZ_VELERO_SERVICE_PRINCIPAL_NAME" --query '[0].appId' -o tsv)"
AZ_VELERO_SERVICE_PRINCIPAL_DESCRIPTION="Used by Velero to access Azure resources"

printf "Update credentials in keyvault..."
update_service_principal_credentials_in_az_keyvault "${AZ_VELERO_SERVICE_PRINCIPAL_NAME}" "${AZ_VELERO_SERVICE_PRINCIPAL_ID}" "${AZ_VELERO_SERVICE_PRINCIPAL_PASSWORD}" "${AZ_VELERO_SERVICE_PRINCIPAL_DESCRIPTION}"
printf "Done.\n"

# Clean up
unset AZ_VELERO_SERVICE_PRINCIPAL_PASSWORD # Clear credentials from memory

#######################################################################################
### Velero custom RBAC clusterrole
###
RBAC_CLUSTERROLE="velero-admin"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: $RBAC_CLUSTERROLE
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
rules:
- apiGroups:
  - "*"
  resources:
  - "*"
  verbs:
  - "*"
- nonResourceURLs: ["*"]
  verbs: ["*"]
EOF                            

#######################################################################################
### END
### 

echo ""
echo "WARNING!"
echo "You _must_ manually set team members as owners for the service principal \"$AZ_VELERO_SERVICE_PRINCIPAL_NAME\","
echo "as this is not possible to do by script (yet)."
echo ""

echo ""
echo "Bootstrap of Velero is done!"

