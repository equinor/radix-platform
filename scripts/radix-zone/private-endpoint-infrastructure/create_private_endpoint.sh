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

if [[ -z "$TARGET_RESOURCE_RESOURCE_ID" ]]; then
    echo "ERROR: Please provide TARGET_RESOURCE_RESOURCE_ID" >&2
    exit 1
elif [[ ${TARGET_RESOURCE_RESOURCE_ID:0:15} != "/subscriptions/" ]]; then
    echo "ERROR: Resource ID is invalid. Quitting..." >&2
    exit 1
fi

if [[ -z ${TARGET_SUBRESOURCE} && -z $(echo ${TARGET_RESOURCE_RESOURCE_ID} | grep "/providers/Microsoft.Network/privateLinkServices") ]]; then
    echo "ERROR: A target subresource is required for any target resources other than Private Link Services: https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-link-resource." >&2
    echo "ERROR: Quitting..." >&2
    exit 1
fi

if [[ -z "$RADIX_PE_KV_SECRET_NAME" ]]; then
    RADIX_PE_KV_SECRET_NAME="radix-private-endpoints"
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Define associative array to map PE subresource and DNS Zone
###

declare -A DNS_ZONE_MAP=(
    ["vault"]="privatelink.vaultcore.azure.net" 
    ["blob"]="privatelink.blob.core.windows.net"
    ["postgresqlServer"]="privatelink.postgres.database.azure.com"
    ["mysqlServer"]="privatelink.mysql.database.azure.com"
    ["mariadbServer"]="privatelink.mariadb.database.azure.com"
    ["sqlServer"]="privatelink.database.windows.net"
)

dns_zone=${DNS_ZONE_MAP[$TARGET_SUBRESOURCE]}

if [[ -z ${dns_zone} ]]; then
warning_msg=$(cat <<-END
    WARNING: Target sub-resource ${TARGET_SUBRESOURCE} does not map to a private DNS zone. If an appropriate mapping is documented 
    at https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration, you can add 
    this mapping to the logic in this script. If you proceed without a mapping, this script will not create a DNS record in our 
    Private DNS Zones to make the FQDN of the target resource resolve to the Private Endpoint IP address from within Radix.

    However, a default DNS record by name of ${RESOURCE_NAME}.${AZ_PRIVATE_DNS_ZONES[-1]} will still be created. If you're creating
    a PE to a service which does not need to resolve to a particular FQDN, like an Azure Load Balancer or an Azure Application Gateway,
    this is sufficient.
END
)
    echo "$warning_msg" >&2
    if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Proceed without creating service-specific DNS record for PE? (Y/n) " yn
            case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) echo ""; echo "Quitting."; exit 0;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
    fi
fi

RESOURCE_NAME=$(echo $TARGET_RESOURCE_RESOURCE_ID | awk -F '/' '{print $NF}')

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
echo -e "Create Private Endpoint will use the following configuration:"
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
echo -e "   -  TARGET_RESOURCE_RESOURCE_ID      : $TARGET_RESOURCE_RESOURCE_ID"
echo -e "   -  TARGET_SUBRESOURCE               : ${TARGET_SUBRESOURCE:-empty (Private Link service)}"
echo -e "   -  RESOURCE_NAME                    : ${RESOURCE_NAME}"
echo -e "   -  PRIVATE_DNS_RECORD               : ${RESOURCE_NAME}"
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

PRIVATE_ENDPOINT_ID=$(az network private-endpoint show \
    --name "${PRIVATE_ENDPOINT_NAME}" \
    --resource-group "${AZ_RESOURCE_GROUP_VNET_HUB}" \
    --query id \
    --output tsv \
    2>/dev/null)

    if [[ -z ${PRIVATE_ENDPOINT_ID} ]]; then
    echo "Creating private endpoint..."

    PRIVATE_ENDPOINT_ID=$(az network private-endpoint create \
        --name "${PRIVATE_ENDPOINT_NAME}" \
        --resource-group "${AZ_RESOURCE_GROUP_VNET_HUB}" \
        --connection-name "${PRIVATE_ENDPOINT_NAME}" \
        --private-connection-resource-id "${TARGET_RESOURCE_RESOURCE_ID}" \
        --group-id "${TARGET_SUBRESOURCE}" \
        --subnet "${AZ_VNET_HUB_SUBNET_NAME}" \
        --vnet-name "${AZ_VNET_HUB_NAME}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --location "${AZ_RADIX_ZONE_LOCATION}" \
        --manual-request true \
        --request-message "Radix Private Link" \
        --query id \
        --output tsv \
        --only-show-errors) || { echo "ERROR: Something went wrong when creating Private Endpoint." >&2; exit 1; }
else
    echo "Private Endpoint already exists."
fi


#######################################################################################
### Get PE NIC IP address
###

private_endpoint_nic_id=$(az network private-endpoint show --ids ${PRIVATE_ENDPOINT_ID} --query networkInterfaces[0].id --output tsv)
if [[ -n ${private_endpoint_nic_id} ]]; then
    nic_private_ip=$(az network nic show --ids ${private_endpoint_nic_id} --query ipConfigurations[0].privateIPAddress --output tsv 2>/dev/null)
    if [[ -z ${nic_private_ip} ]]; then
        echo "ERROR: Could not get Private IP of NIC ${private_endpoint_nic_id}." >&2
        exit 1
    fi
else
    echo "ERROR: Could not get NIC ID of Private Endpoint ${private_endpoint_id}." >&2
    exit 1
fi

#######################################################################################
### Create Private DNS Record
###

function create-private-dns-record() {
    local private_endpoint_id=$1
    local nic_private_ip=$2
    local record_name=$3
    local private_dns_zone=$4

    private_dns_record_name=$(az network private-dns record-set a list \
        --resource-group ${AZ_RESOURCE_GROUP_VNET_HUB} \
        --zone-name ${private_dns_zone} \
        --query "[?aRecords[?ipv4Address=='${nic_private_ip}']].name" |
        jq -r .[0])

    if [[ ${private_dns_record_name} == "null" ]]; then
        echo "Creating Private DNS Record..."
        private_dns_record_name=$(az network private-dns record-set a add-record \
            --ipv4-address ${nic_private_ip} \
            --record-set-name ${record_name} \
            --zone-name ${private_dns_zone} \
            --resource-group ${AZ_RESOURCE_GROUP_VNET_HUB} \
            --query name \
            --output tsv)
        if [[ -z ${private_dns_record_name} ]]; then
            echo "ERROR: Could not create Private DNS Record. Quitting..." >&2
            return 1
        else
            echo "Created Private DNS Record with name ${private_dns_record_name}."
            return
        fi
    else
        echo "ERROR: Private DNS Record already exists: ${private_dns_record_name}." >&2
        return 1
    fi
}

create-private-dns-record "$PRIVATE_ENDPOINT_ID" "${nic_private_ip}" "$PRIVATE_ENDPOINT_NAME" "${AZ_PRIVATE_DNS_ZONES[-1]}" && save-dns-record-to-kv
if [[ -n ${dns_zone} ]]; then
    create-private-dns-record "$PRIVATE_ENDPOINT_ID" "${nic_private_ip}" "$RESOURCE_NAME" "${dns_zone}" && save-dns-record-to-kv
fi
save-pe-to-kv

function save-pe-to-kv() {
    local pe_id=$1

    existing_secret="$(az keyvault secret show \
        --vault-name ${AZ_RESOURCE_KEYVAULT} \
        --name ${RADIX_PE_KV_SECRET_NAME} \
        | jq '.value | fromjson')"
    
    # Check if PE exists in secret
    if [[ -z $(echo ${existing_secret} | jq '.[] | select(.private_endpoint_id=="'${pe_id}'").name') ]]; then
        # Does not exist in secret
        # echo "Getting JSON"
        pe_definition=$(az network private-endpoint show \
            --ids ${pe_id} \
            2>/dev/null)
        json=$(echo ${pe_definition} | jq '. |
        {
            private_endpoint_id: .id,
            private_endpoint_name: .name,
            private_endpoint_resource_group: .resourceGroup,
            private_endpoint_location: .location,
            target_resource_id: .manualPrivateLinkServiceConnections[].privateLinkServiceId,
            target_subresource: .manualPrivateLinkServiceConnections[].groupIds[],
        }')
        echo "$json"
        echo "Updating keyvault secret..."
        new_secret=$(echo ${existing_secret} | jq '. += ['"$(echo ${json} | jq -c)"']')
        az keyvault secret set --name ${RADIX_PE_KV_SECRET_NAME} --vault-name ${AZ_RESOURCE_KEYVAULT} --value "${new_secret}" >/dev/null
        echo "Done."
    else
        echo "Private endpoint exists in keyvault secret."
    fi
}

# make function to save PE
# make function to save DNS record

#######################################################################################
### Save information in keyvault
###

# Make sure necessary variables are set.
if [[ -z ${PRIVATE_ENDPOINT_ID} ]]; then
    echo "ERROR: Missing variable PRIVATE_ENDPOINT_ID." >&2
    exit 1
fi

if [[ -z ${NIC_PRIVATE_IP} ]]; then
    echo "ERROR: Missing variable NIC_PRIVATE_IP." >&2
    exit 1
fi

if [[ -z ${PRIVATE_DNS_RECORD_NAME} ]]; then
    echo "ERROR: Missing variable PRIVATE_DNS_RECORD_NAME." >&2
    exit 1
fi

# Get secret
SECRET="$(az keyvault secret show \
        --vault-name ${AZ_RESOURCE_KEYVAULT} \
        --name ${RADIX_PE_KV_SECRET_NAME} \
        | jq '.value | fromjson')"

# Check if PE exists in secret
if [[ -z $(echo ${SECRET} | jq '.[] | select(.private_endpoint_id=="'${PRIVATE_ENDPOINT_ID}'").name') ]]; then
    # Does not exist in secret
    echo "Getting JSON"
    PRIVATE_ENDPOINT=$(az network private-endpoint show \
        --ids ${PRIVATE_ENDPOINT_ID} \
        2>/dev/null)
    JSON=$(echo ${PRIVATE_ENDPOINT} | jq '. |
    {
        private_endpoint_id: .id,
        private_endpoint_name: .name,
        private_endpoint_resource_group: .resourceGroup,
        private_endpoint_location: .location,
        private_endpoint_nic_ipv4: "'${NIC_PRIVATE_IP}'",
        private_dns_zone_record_name: "'${PRIVATE_DNS_RECORD_NAME}'",
        target_resource_id: .manualPrivateLinkServiceConnections[].privateLinkServiceId,
        target_subresource: "'${TARGET_SUBRESOURCE}'",
    }')
    echo "$JSON"
    echo "Updating keyvault secret..."
    NEW_SECRET=$(echo ${SECRET} | jq '. += ['"$(echo ${JSON} | jq -c)"']')
    az keyvault secret set --name ${RADIX_PE_KV_SECRET_NAME} --vault-name ${AZ_RESOURCE_KEYVAULT} --value "${NEW_SECRET}" >/dev/null
    echo "Done."
else
    echo "Private endpoint exists in keyvault secret."
fi

echo ""
echo "Done creating Private Endpoint."
