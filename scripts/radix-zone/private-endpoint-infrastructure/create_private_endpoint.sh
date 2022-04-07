#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Create a Private Endpoint from Radix which connects to a resource in a different subscription.
# Save the json of the resource to a secret in the keyvault for reference.

#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE_ENV                  : Path to *.env file
# - PRIVATE_ENDPOINT_NAME           : Name of the Private Endpoint to be created. i.e. pe-team-resourcetype-environment or pe-radix-privatelinkservice-prod
# - TARGET_RESOURCE_RESOURCE_ID     : The resource ID of the resource to connect to. i.e. /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroup/providers/Microsoft.Storage/storageAccounts/myStorageAccount
# - TARGET_SUBRESOURCE              : The subresource of the target resource. i.e. file https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-link-resource

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.


#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix_zone_dev.env PRIVATE_ENDPOINT_NAME="" TARGET_RESOURCE_RESOURCE_ID="" TARGET_SUBRESOURCE="" ./create_private_endpoint.sh

#######################################################################################
### START
###

#######################################################################################
### Read inputs and configs
###

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

if [[ -z "$PRIVATE_ENDPOINT_NAME" ]]; then
    echo "Please provide PRIVATE_ENDPOINT_NAME" >&2
    exit 1
fi

if [[ -z "$TARGET_RESOURCE_RESOURCE_ID" ]]; then
    echo "Please provide TARGET_RESOURCE_RESOURCE_ID" >&2
    exit 1
elif [[ ${TARGET_RESOURCE_RESOURCE_ID:0:15} != "/subscriptions/" ]]; then
    echo "Error: Resource ID is invalid. Quitting..."
    exit 1
fi

if [[ -z "$TARGET_SUBRESOURCE" ]]; then
    echo "Please provide TARGET_SUBRESOURCE (https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-link-resource)" >&2
    exit 1
fi

if [[ -z "$RADIX_PE_KV_SECRET_NAME" ]]; then
    RADIX_PE_KV_SECRET_NAME="radix-private-endpoints"
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

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Bootstrap Private Endpoint infrastructure will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION_ID               : $AZ_SUBSCRIPTION_ID"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e "   -  AZ_RESOURCE_GROUP_VNET_HUB       : $AZ_RESOURCE_GROUP_VNET_HUB"
echo -e "   -  AZ_VNET_HUB_NAME                 : $AZ_VNET_HUB_NAME"
echo -e "   -  AZ_VNET_HUB_SUBNET_NAME          : $AZ_VNET_HUB_SUBNET_NAME"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  RADIX_PE_KV_SECRET_NAME          : $RADIX_PE_KV_SECRET_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  PRIVATE_ENDPOINT_NAME            : $PRIVATE_ENDPOINT_NAME"
echo -e "   -  REMOTE_RESOURCE_RESOURCE_ID      : $TARGET_RESOURCE_RESOURCE_ID"
echo -e "   -  TARGET_SUBRESOURCE               : $TARGET_SUBRESOURCE"
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

#######################################################################################
### Create private endpoint
###

echo "Creating private endpoint..."
CREATE_PRIVATE_ENDPOINT=$(az network private-endpoint create \
    --name ${PRIVATE_ENDPOINT_NAME} \
    --resource-group ${AZ_RESOURCE_GROUP_VNET_HUB} \
    --connection-name ${PRIVATE_ENDPOINT_NAME} \
    --private-connection-resource-id ${TARGET_RESOURCE_RESOURCE_ID} \
    --group-id ${TARGET_SUBRESOURCE} \
    --subnet ${AZ_VNET_HUB_SUBNET_NAME} \
    --vnet-name ${AZ_VNET_HUB_NAME} \
    --subscription ${AZ_SUBSCRIPTION_ID} \
    --location ${AZ_INFRASTRUCTURE_REGION} \
    --manual-request true \
    --request-message "Radix Private Link")

if [[ $(echo ${CREATE_PRIVATE_ENDPOINT} | jq -r .provisioningState) != "Succeeded" ]]; then
    echo "ERROR: Something went wrong when creating Private Endpoint:"
    exit 1
else
    echo "Done."
fi

#######################################################################################
### Save information in keyvault
###

# Get secret
SECRET="$(az keyvault secret show \
        --vault-name ${AZ_RESOURCE_KEYVAULT} \
        --name ${RADIX_PE_KV_SECRET_NAME} \
        | jq '.value | fromjson')"

# Check if PE exists in secret
if [[ -z $(echo ${SECRET} | jq '.[] | select(.id=="'$(echo ${CREATE_PRIVATE_ENDPOINT} | jq -r .id)'").name') ]]; then
    echo "Updating keyvault secret..."
    NEW_SECRET=$(echo ${SECRET} | jq '. += ['"$(echo ${CREATE_PRIVATE_ENDPOINT} | jq -c)"']')
    az keyvault secret set --name ${RADIX_PE_KV_SECRET_NAME} --vault-name ${AZ_RESOURCE_KEYVAULT} --value "${NEW_SECRET}" >/dev/null
    echo "Done."
else
    echo "Private endpoint exists in keyvault secret."
fi

echo ""
echo "Done creating Private Endpoint."
