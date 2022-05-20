#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Delete a Private Endpoint and remove the JSON from the keyvault secret.

#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE_ENV                  : Path to *.env file
# - PRIVATE_ENDPOINT_NAME           : Name of the Private Endpoint to be created. i.e. pe-team-resourcetype-environment or pe-radix-privatelinkservice-prod

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.


#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix_zone_dev.env PRIVATE_ENDPOINT_NAME="" ./delete_private_endpoint.sh

#######################################################################################
### START
###

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

if [[ -z "$PRIVATE_ENDPOINT_NAME" ]]; then
    echo "ERROR: Please provide PRIVATE_ENDPOINT_NAME" >&2
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
echo -e "Delete Private Endpoint will use the following configuration:"
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
### Delete Private Endpoint
###

PRIVATE_ENDPOINT_ID=$(az network private-endpoint show \
    --name ${PRIVATE_ENDPOINT_NAME} \
    --resource-group ${AZ_RESOURCE_GROUP_VNET_HUB} \
    --query id \
    --output tsv \
    2>/dev/null)

if [[ -z ${PRIVATE_ENDPOINT_ID} ]]; then
    echo "Private Endpoint with name ${PRIVATE_ENDPOINT_NAME} was not found."
else
    echo "Deleting private endpoint ${PRIVATE_ENDPOINT_NAME}..."
    az network private-endpoint delete --ids ${PRIVATE_ENDPOINT_ID}
    echo "Done."
fi

#######################################################################################
### Delete Private DNS Record
###

PRIVATE_DNS_RECORD=$(az network private-dns record-set a list \
    --resource-group ${AZ_RESOURCE_GROUP_VNET_HUB} \
    --zone-name ${AZ_PRIVATE_DNS_ZONES[-1]} \
    --query "[?name=='${PRIVATE_ENDPOINT_NAME}']")

PRIVATE_DNS_RECORD_NAME=$(echo ${PRIVATE_DNS_RECORD} | jq -r .[0].name)
PRIVATE_DNS_RECORD_IP=$(echo ${PRIVATE_DNS_RECORD} | jq -r .[0].aRecords[0].ipv4Address)

if [[ -n ${PRIVATE_DNS_RECORD_IP} ]]; then
    echo "Deleting Private DNS Record..."
    az network private-dns record-set a remove-record \
        --ipv4-address ${PRIVATE_DNS_RECORD_IP} \
        --record-set-name ${PRIVATE_DNS_RECORD_NAME} \
        --zone-name ${AZ_PRIVATE_DNS_ZONES[-1]} \
        --resource-group ${AZ_RESOURCE_GROUP_VNET_HUB}
    echo "Deleted Private DNS Record with name ${PRIVATE_DNS_RECORD_NAME}."
else
    echo "Private DNS Record for the Private Link ${PRIVATE_ENDPOINT_NAME} does not exist."
fi

#######################################################################################
### Delete information from keyvault secret
###

# Get secret
SECRET="$(az keyvault secret show \
        --vault-name ${AZ_RESOURCE_KEYVAULT} \
        --name ${RADIX_PE_KV_SECRET_NAME} \
        | jq '.value | fromjson')"

# Check if PE exists in secret
if [[ -n $(echo ${SECRET} | jq '.[] | select(.private_endpoint_name=="'${PRIVATE_ENDPOINT_NAME}'" and .private_endpoint_resource_group=="'${AZ_RESOURCE_GROUP_VNET_HUB}'").name') ]]; then
    NEW_SECRET=$(echo ${SECRET} | jq '. | del(.[] | select(.private_endpoint_name=="'${PRIVATE_ENDPOINT_NAME}'" and .private_endpoint_resource_group=="'${AZ_RESOURCE_GROUP_VNET_HUB}'"))')
    echo "Updating keyvault secret..."
    az keyvault secret set --name ${RADIX_PE_KV_SECRET_NAME} --vault-name ${AZ_RESOURCE_KEYVAULT} --value "${NEW_SECRET}" >/dev/null
    echo "Done."
else
    echo "Private endpoint does not exist in keyvault secret."
fi

echo ""
echo "Done deleting Private Endpoint."
