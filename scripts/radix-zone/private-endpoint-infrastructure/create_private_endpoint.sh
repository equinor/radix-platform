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

# With dynamically allocated IP address
# RADIX_ZONE_ENV=../radix_zone_dev.env PRIVATE_ENDPOINT_NAME="" TARGET_RESOURCE_RESOURCE_ID="" TARGET_SUBRESOURCE="" ./create_private_endpoint.sh

# With statically allocated IP address
# RADIX_ZONE_ENV=../radix_zone_dev.env PRIVATE_ENDPOINT_NAME="" TARGET_RESOURCE_RESOURCE_ID="" TARGET_SUBRESOURCE="" IP_ADDRESS="10.0.0.5" ./create_private_endpoint.sh

#######################################################################################
### START
###

#######################################################################################
### Check for prerequisites binaries
###

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.46.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI.${normal}\n"
    exit 1
fi

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

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Define associative array to map PE subresource and DNS Zone. Append additional entries to this map from
### https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-link-resource
### when required
###

declare -A DNS_ZONE_MAP=(
    ["vault"]="privatelink.vaultcore.azure.net"
    ["blob"]="privatelink.blob.core.windows.net"
    ["postgresqlServer"]="privatelink.postgres.database.azure.com"
    ["mysqlServer"]="privatelink.mysql.database.azure.com"
    ["mariadbServer"]="privatelink.mariadb.database.azure.com"
    ["sqlServer"]="privatelink.database.windows.net"
)

dns_zone=${DNS_ZONE_MAP[$TARGET_SUBRESOURCE]} 2>/dev/null # can't figure out how to properly suppress this error message

unset yn
if [[ -z ${dns_zone} ]]; then
    dns_zone=${AZ_PRIVATE_DNS_ZONES[-1]}
    warning_msg=$(
        cat <<-END
        WARNING: Target sub-resource ${TARGET_SUBRESOURCE} does not map to a private DNS zone. If an appropriate mapping is documented 
        at https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration, you can add 
        this mapping to the logic in this script. If you proceed without a mapping, this script will not create a DNS record in our 
        Private DNS Zones to make the current FQDN of the target resource resolve to the Private Endpoint's IP address from within Radix.
        E.g., if you create a PE to a blob containerin a storage account with FQDN radixblob.core.windows.net _without_ creating the 
        appropriate record in the private DNS zone .privatelink.blob.core.windows.net, the result will be that radixblob.core.windows.net
        is resolvable outside of the Radix cluster, but _not_ inside the Radix cluster.

        However, a default DNS record by name of ${RESOURCE_NAME}.${dns_zone} will still be created. If you're creating
        a PE to a service which does not resolve to a particular FQDN by default, like an Azure Load Balancer or an Azure Application 
        Gateway, this is appropriate.
END
    )
    if [[ $USER_PROMPT == true ]]; then
        echo "$warning_msg" >&2
        while true; do
            read -p "Proceed without creating service-specific DNS record for PE? (Y/n) " yn
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
echo -e "   -  PRIVATE_DNS_RECORD               : ${RESOURCE_NAME}.${dns_zone}"
echo -e "   -  IP_ADDRESS                       : ${IP_ADDRESS:-Dynamically allocated}"
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

#######################################################################################
### Create private endpoint
###

if [ -z $TARGET_SUBRESOURCE ]; then
    group_id_arg=""
else
    group_id_arg='--group-id '${TARGET_SUBRESOURCE}''
fi

if [ -z $IP_ADDRESS ]; then
    ip_config_arg=""
else
    # TODO: take into account case when TARGET_SUBRESOURCE is empty
    if [ -z $TARGET_SUBRESOURCE ]; then
        ip_config_arg=$'--ip-configs [{name:static-ip-address,private-ip-address:'${IP_ADDRESS}$'}]'
    else
        ip_config_arg=$'--ip-configs [{name:static-ip-address,private-ip-address:'${IP_ADDRESS}$',groupId:'${TARGET_SUBRESOURCE}$',memberName:'${TARGET_SUBRESOURCE}$'}]'
    fi
fi

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
        ${group_id_arg} \
        ${ip_config_arg} \
        --subnet "${AZ_VNET_HUB_SUBNET_NAME}" \
        --vnet-name "${AZ_VNET_HUB_NAME}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --location "${AZ_RADIX_ZONE_LOCATION}" \
        --manual-request true \
        --request-message RadixPrivateLink \
        --query id \
        --output tsv \
        --only-show-errors) || {
        echo "ERROR: Something went wrong when creating Private Endpoint." >&2
        exit 1
    }
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
    echo "ERROR: Could not get NIC ID of Private Endpoint ${PRIVATE_ENDPOINT_ID}." >&2
    exit 1
fi

az network private-endpoint dns-zone-group create \
    --endpoint-name ${PRIVATE_ENDPOINT_NAME} \
    --name default \
    --private-dns-zone ${dns_zone} \
    --resource-group ${AZ_RESOURCE_GROUP_VNET_HUB} \
    --zone-name $(echo ${dns_zone} | tr '.' '_') \
    --only-show-errors >/dev/null || {
    echo "ERROR: Something went wrong when creating DNS zone integration with Private Endpoint." >&2
    exit 1
}

#######################################################################################
### Save information in keyvault
###

function save-pe-to-kv() {
    local pe_id=$1
    local ip_address=$2

    existing_secret="$(az keyvault secret show \
        --vault-name ${AZ_RESOURCE_KEYVAULT} \
        --name ${RADIX_PE_KV_SECRET_NAME} |
        jq '.value | fromjson')"
    if [ "$existing_secret" == "" ]; then
        existing_secret='[]'
    fi

    # Check if PE exists in secret
    if [[ -z $(echo ${existing_secret} | jq '.[] | select(.private_endpoint_id=="'${pe_id}'").name') ]]; then
        # Does not exist in secret
        # echo "Getting JSON"
        pe_definition=$(az network private-endpoint show \
            --ids ${pe_id} \
            2>/dev/null)
        target_subresource=$(echo $pe_definition | jq .manualPrivateLinkServiceConnections[].groupIds[] --raw-output 2>/dev/null)
        json=$(echo ${pe_definition} | jq '. |
        {
            private_endpoint_id: .id,
            private_endpoint_name: .name,
            private_endpoint_resource_group: .resourceGroup,
            private_endpoint_location: .location,
            target_resource_id: .manualPrivateLinkServiceConnections[].privateLinkServiceId,
            target_subresource: "'${target_subresource}'",
            ip_address: "'${ip_address}'"
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

save-pe-to-kv "${PRIVATE_ENDPOINT_ID}" "${nic_private_ip}"

echo ""
echo "Done creating Private Endpoint."
