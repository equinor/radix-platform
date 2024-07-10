#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap radix environment infrastructure shared by all radix-zones

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
echo "Start bootstrap of base infrastructure... "

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
    printf "\n\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.46.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI.${normal}\n"
    exit 1
fi

hash uuidgen 2>/dev/null || {
    echo -e "\nERROR: uuidgen not found in PATH. Exiting..." >&2
    exit 1
}

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

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Load dependencies
LIB_SERVICE_PRINCIPAL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../service-principals-and-aad-apps/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
    echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_SERVICE_PRINCIPAL_PATH"
fi
LIB_MANAGED_IDENTITY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../service-principals-and-aad-apps/lib_managed_identity.sh"
if [[ ! -f "$LIB_MANAGED_IDENTITY_PATH" ]]; then
    echo "ERROR: The dependency LIB_MANAGED_IDENTITY_PATH=$LIB_MANAGED_IDENTITY_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_MANAGED_IDENTITY_PATH"
fi
LIB_ACR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../radix-zone/base-infrastructure/lib_acr.sh"
if [[ ! -f "$LIB_ACR_PATH" ]]; then
    echo "ERROR: The dependency LIB_ACR_PATH=$LIB_ACR_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_ACR_PATH"
fi
LIB_UTIL_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../utility/util.sh"
if [[ ! -f "$LIB_UTIL_PATH" ]]; then
    echo "ERROR: The dependency LIB_UTIL_PATH=$LIB_UTIL_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_UTIL_PATH"
fi
WHITELIST_IP_IN_ACR_SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../utility/lib_ip_whitelist.sh"
if [[ ! -f "$WHITELIST_IP_IN_ACR_SCRIPT_PATH" ]]; then
    echo "ERROR: The dependency WHITELIST_IP_IN_ACR_SCRIPT_PATH=$WHITELIST_IP_IN_ACR_SCRIPT_PATH is invalid, the file does not exist." >&2
    exit 1
fi
AD_APP_MANIFEST_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/manifest-server.json"
if [[ ! -f "$AD_APP_MANIFEST_PATH" ]]; then
    echo "ERROR: The dependency AD_APP_MANIFEST_PATH=$AD_APP_MANIFEST_PATH is invalid, the file does not exist." >&2
    exit 1
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

exit_if_user_does_not_have_required_ad_role

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Bootstrap of base infrastructure will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                                  : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION                      : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                           : $RADIX_ENVIRONMENT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_GROUP_CLUSTERS                  : $AZ_RESOURCE_GROUP_CLUSTERS"
echo -e "   -  AZ_RESOURCE_GROUP_COMMON                    : $AZ_RESOURCE_GROUP_COMMON"
echo -e "   -  AZ_RESOURCE_GROUP_MONITORING                : $AZ_RESOURCE_GROUP_MONITORING"
echo -e ""
echo -e "   -  AZ_RESOURCE_KEYVAULT                        : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  AZ_IPPRE_OUTBOUND_NAME                      : $AZ_IPPRE_OUTBOUND_NAME"
echo -e "   -  AZ_IPPRE_OUTBOUND_IP_PREFIX                 : $AZ_IPPRE_OUTBOUND_IP_PREFIX"
echo -e "   -  AZ_IPPRE_OUTBOUND_LENGTH                    : $AZ_IPPRE_OUTBOUND_LENGTH"
echo -e "   -  AZ_IPPRE_INBOUND_NAME                       : $AZ_IPPRE_INBOUND_NAME"
echo -e "   -  AZ_IPPRE_INBOUND_IP_PREFIX                  : $AZ_IPPRE_INBOUND_IP_PREFIX"
echo -e "   -  AZ_IPPRE_INBOUND_LENGTH                     : $AZ_IPPRE_INBOUND_LENGTH"
echo -e "   -  AZ_RESOURCE_CONTAINER_REGISTRY              : $AZ_RESOURCE_CONTAINER_REGISTRY"
echo -e "   -  AZ_RESOURCE_DNS                             : $AZ_RESOURCE_DNS"
echo -e ""
echo -e "   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER    : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER"
echo -e "   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD      : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD"
echo -e "   -  APP_REGISTRATION_WEB_CONSOLE                : $APP_REGISTRATION_WEB_CONSOLE"
echo -e "   -  APP_REGISTRATION_GRAFANA                    : $APP_REGISTRATION_GRAFANA"
echo -e "   -  APP_REGISTRATION_SERVICENOW_SERVER          : $APP_REGISTRATION_SERVICENOW_SERVER"
echo -e ""
echo -e "   -  MI_AKS                                      : $MI_AKS"
echo -e "   -  MI_AKSKUBELET                               : $MI_AKSKUBELET"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                             : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                                     : $(az account show --query user.name -o tsv)"
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


#######################################################################################
### App registration permissions
###

function update_app_registrations(){
    update_app_registration_permissions="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../update_app_registration_permissions.sh"
    if [[ ! -f "$update_app_registration_permissions" ]]; then
        echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$update_app_registration_permissions is invalid, the file does not exist." >&2
        exit 1
    fi
}

#######################################################################################
### Resource groups
###

# function create_resource_groups() {
#     printf "Creating all resource groups..."
#     az group create \
#         --location "${AZ_RADIX_ZONE_LOCATION}" \
#         --name "${AZ_RESOURCE_GROUP_CLUSTERS}" \
#         --subscription "${AZ_SUBSCRIPTION_ID}" \
#         --output none
    
#     az group create \
#         --location "${AZ_RADIX_ZONE_LOCATION}" \
#         --name "${AZ_RESOURCE_GROUP_COMMON}" \
#         --subscription "${AZ_SUBSCRIPTION_ID}" \
#         --output none
    
#     az group create \
#         --location "${AZ_RADIX_ZONE_LOCATION}" \
#         --name "${AZ_RESOURCE_GROUP_MONITORING}" \
#         --subscription "${AZ_SUBSCRIPTION_ID}" \
#         --output none
# }

#######################################################################################
### Common resources
###

function create_common_resources() {
    printf "Creating key vault: %s...\n" "${AZ_RESOURCE_KEYVAULT}"
    az keyvault create \
        --name "${AZ_RESOURCE_KEYVAULT}" \
        --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --enable-purge-protection \
        --output none
    printf "...Done\n"

    printf "Set access policy for group \"Radix Platform Operators\" in key vault: %s...\n" "${AZ_RESOURCE_KEYVAULT}"
    az keyvault set-policy \
        --object-id "$(az ad group show --group "Radix Platform Operators" --query id --output tsv --only-show-errors)" \
        --name "${AZ_RESOURCE_KEYVAULT}" \
        --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --certificate-permissions get list update create import delete recover backup restore managecontacts manageissuers getissuers listissuers setissuers deleteissuers \
        --key-permissions get list update create import delete recover backup restore \
        --secret-permissions get list set delete recover backup restore \
        --storage-permissions \
        --output none \
        --only-show-errors
    printf "...Done\n"

    printf "Creating Azure DNS: %s\n" "${AZ_RESOURCE_DNS}"
    az network dns zone create \
        --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
        --name "${AZ_RESOURCE_DNS}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --output none
    printf "...Done\n"
    # DNS CAA
    if [ "$RADIX_ENVIRONMENT" = "prod" ]; then
        printf "Adding CAA records..."
        az network dns record-set caa add-record \
            --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
            --zone-name "${AZ_RESOURCE_DNS}" \
            --subscription "${AZ_SUBSCRIPTION_ID}" \
            --record-set-name @ \
            --flags 0 \
            --tag "issue" \
            --value "letsencrypt.org" \
            --output none
        
        az network dns record-set caa add-record \
            --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
            --zone-name "${AZ_RESOURCE_DNS}" \
            --subscription "${AZ_SUBSCRIPTION_ID}" \
            --record-set-name @ \
            --flags 0 \
            --tag "issue" \
            --value "digicert.com" \
            --output none
        
        az network dns record-set caa add-record \
            --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
            --zone-name "${AZ_RESOURCE_DNS}" \
            --subscription "${AZ_SUBSCRIPTION_ID}" \
            --record-set-name @ \
            --flags 0 \
            --tag "issue" \
            --value "godaddy.com" \
            --output none
        printf "...Done\n"
    fi
    ../private-endpoint-infrastructure/bootstrap.sh
}

function create_outbound_public_ip_prefix() {
    # Create public ip prefixes
    if [[ -n $AZ_IPPRE_OUTBOUND_NAME ]]; then
        if [[ -z $(az network public-ip prefix show --name "${AZ_IPPRE_OUTBOUND_NAME}" --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --subscription "${AZ_SUBSCRIPTION_ID}" --query "name" -otsv 2>/dev/null) ]]; then
            printf "Public IP Prefix %s does not exist.\n" "${AZ_IPPRE_OUTBOUND_NAME}"
            if [[ $USER_PROMPT == true ]]; then
                while true; do
                    read -r -p "Create Public IP Prefix: ${AZ_IPPRE_OUTBOUND_NAME}? (Y/n) " yn
                    case $yn in
                    [Yy]*) break ;;
                    [Nn]*)
                        echo ""
                        echo "Return."
                        return
                        ;;
                    *) echo "Please answer yes or no." ;;
                    esac
                done
                printf "Creating Public IP Prefix: %s...\n" "${AZ_IPPRE_OUTBOUND_NAME}"
                az network public-ip prefix create \
                    --length "${AZ_IPPRE_OUTBOUND_LENGTH}" \
                    --name "${AZ_IPPRE_OUTBOUND_NAME}" \
                    --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
                    --subscription "${AZ_SUBSCRIPTION_ID}" \
                    --output none
                printf "...Done.\n"
            fi
        else
            printf "Public IP Prefix %s already exists." "${AZ_IPPRE_OUTBOUND_NAME}"
        fi
        # Create IPs
        echo "Creating IPs in Public IP Prefix ${AZ_IPPRE_OUTBOUND_NAME}..."
        IPPRE_OUTBOUND_IP_NUMBER=$(az network public-ip prefix show \
            --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
            --name ${AZ_IPPRE_OUTBOUND_NAME} \
            --subscription ${AZ_SUBSCRIPTION_ID} \
            --query publicIPAddresses |
            jq -r .[].id |
            wc -l |
            sed 's/^ *//g')
        while true; do
            # Get current number of IPs, add trailing 0s and increment by 1
            IPPRE_OUTBOUND_IP_NUMBER=$(printf %03d $(($IPPRE_OUTBOUND_IP_NUMBER + 1)))
            IP_NAME="${AZ_IPPRE_OUTBOUND_IP_PREFIX}-${IPPRE_OUTBOUND_IP_NUMBER}"
            if [[ $(az network public-ip create \
                --public-ip-prefix /subscriptions/$AZ_SUBSCRIPTION_ID/resourcegroups/$AZ_RESOURCE_GROUP_COMMON/providers/microsoft.network/publicIPPrefixes/$AZ_IPPRE_OUTBOUND_NAME \
                --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
                --name ${IP_NAME} \
                --subscription ${AZ_SUBSCRIPTION_ID} \
                --sku Standard \
                2>/dev/null) ]]; then
                echo "Created ip $IP_NAME"
            else
                echo "IPs have been created."
                break
            fi
        done
    else
        printf "Variable AZ_IPPRE_OUTBOUND_NAME not defined."
    fi
}

function create_inbound_public_ip_prefix() {
    if [[ -n $AZ_IPPRE_INBOUND_NAME ]]; then
        if [[ -z $(az network public-ip prefix show --name "${AZ_IPPRE_INBOUND_NAME}" --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --subscription "${AZ_SUBSCRIPTION_ID}" --query "name" -otsv 2>/dev/null) ]]; then
            printf "Public IP Prefix ${AZ_IPPRE_INBOUND_NAME} does not exist.\n"
            if [[ $USER_PROMPT == true ]]; then
                while true; do
                    read -r -p "Create Public IP Prefix: ${AZ_IPPRE_INBOUND_NAME}? (Y/n) " yn
                    case $yn in
                    [Yy]*) break ;;
                    [Nn]*)
                        echo ""
                        echo "Return."
                        return
                        ;;
                    *) echo "Please answer yes or no." ;;
                    esac
                done
                printf "Creating Public IP Prefix: %s...\n" "${AZ_IPPRE_INBOUND_NAME}"
                az network public-ip prefix create \
                    --length "${AZ_IPPRE_INBOUND_LENGTH}" \
                    --name "${AZ_IPPRE_INBOUND_NAME}" \
                    --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
                    --subscription "${AZ_SUBSCRIPTION_ID}" \
                    --output none
                printf "...Done.\n"
            fi
        else
            printf "Public IP Prefix %s already exists." "${AZ_IPPRE_INBOUND_NAME}"
        fi
        # Create IPs
        echo "Creating IPs in Public IP Prefix ${AZ_IPPRE_INBOUND_NAME}..."
        IPPRE_INBOUND_IP_NUMBER=$(az network public-ip prefix show \
            --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
            --name ${AZ_IPPRE_INBOUND_NAME} \
            --subscription ${AZ_SUBSCRIPTION_ID} \
            --query publicIPAddresses |
            jq -r .[].id |
            wc -l |
            sed 's/^ *//g')
        while true; do
            # Get current number of IPs, add trailing 0s and increment by 1
            IPPRE_INBOUND_IP_NUMBER=$(printf %03d $(($IPPRE_INBOUND_IP_NUMBER + 1)))
            IP_NAME="${AZ_IPPRE_INBOUND_IP_PREFIX}-${IPPRE_INBOUND_IP_NUMBER}"
            if [[ $(az network public-ip create \
                --public-ip-prefix /subscriptions/$AZ_SUBSCRIPTION_ID/resourcegroups/$AZ_RESOURCE_GROUP_COMMON/providers/microsoft.network/publicIPPrefixes/$AZ_IPPRE_INBOUND_NAME \
                --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
                --name ${IP_NAME} \
                --subscription ${AZ_SUBSCRIPTION_ID} \
                --sku Standard \
                2>/dev/null) ]]; then
                echo "Created ip $IP_NAME"
            else
                echo "IPs have been created."
                break
            fi
        done
    else
        printf "Variable AZ_IPPRE_INBOUND_NAME not defined."
    fi
}

function create_dns_role_definition_for_cert_manager() {
    # Create DNS TXT Contributor role to be used by Cert Manager
    temp_file_role_definition="/tmp/$(uuidgen)"
    role_name="DNS TXT Contributor"
    cat <<EOF >>${temp_file_role_definition}
    {
        "Name": "${role_name}",
        "Id": "",
        "IsCustom": true,
        "Description": "Can manage DNS TXT records only.",
        "Actions": [
            "Microsoft.Network/dnsZones/TXT/*",
            "Microsoft.Network/dnsZones/read",
            "Microsoft.Authorization/*/read",
            "Microsoft.Insights/alertRules/*",
            "Microsoft.ResourceHealth/availabilityStatuses/read",
            "Microsoft.Resources/deployments/*",
            "Microsoft.Resources/subscriptions/resourceGroups/read",
            "Microsoft.Support/*"
        ],
        "AssignableScopes": [
            "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b",
            "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a"
        ]
    }
EOF
    create_custom_role "${temp_file_role_definition}" "${role_name}"
    rm "${temp_file_role_definition}"

    printf "Creating role assignment..."
    az role assignment create \
        --assignee "$APP_ID" \
        --role "$role_name" \
        --scope "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_COMMON}/providers/Microsoft.Network/dnszones/${AZ_RESOURCE_DNS}" \
        2>/dev/null
    printf "...Done.\n"

}

#######################################################################################
### System users
###

# Create service principals
function create_base_system_users_and_store_credentials() {
    create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER" "Service principal that provide read-only access to container registry"
    create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD" "Service principal that provide push, pull, build in container registry"
    create_service_principal_and_store_credentials "$APP_REGISTRATION_GRAFANA" "Grafana OAuth"
    create_service_principal_and_store_credentials "$APP_REGISTRATION_WEB_CONSOLE" "Used by web console for login and other AD information"
}

function create_servicenow_proxy_server_app_registration() {
    create_app_registration_and_service_principal "$APP_REGISTRATION_SERVICENOW_SERVER"
    set_app_registration_identifier_uris "$APP_REGISTRATION_SERVICENOW_SERVER"

    scopes=$(cat <<-EOF
[
    {
        "value":"Application.Read",
        "type":"User",
        "isEnabled":true,
        "userConsentDescription":"Allows the app to read ServiceNow applications", 
        "userConsentDisplayName":"Read applications from ServiceNow",
        "adminConsentDescription":"Allows the app to read ServiceNow applications", 
        "adminConsentDisplayName":"Read applications from ServiceNow"
    }
]
EOF
)

    set_app_registration_api_scopes "$APP_REGISTRATION_SERVICENOW_SERVER" "$scopes"
}

function update_app_registration() {
    (RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" PERMISSIONS='{"api": "Microsoft Graph","permissions": ["User.Read","GroupMember.Read.All"]}{"api": "Azure Kubernetes Service AAD Server","permissions": ["user.read"]}{"api": "ar-radix-servicenow-proxy-server","permissions": ["Application.Read"]}' source "${update_app_registration_permissions}")
}

# Create managed identities
# function create_managed_identities_and_role_assignments() {
#     # Control plane managed identity: https://docs.microsoft.com/en-us/azure/aks/use-managed-identity#bring-your-own-control-plane-mi
#     create_managed_identity "${MI_AKS}"
#     create_role_assignment_for_identity \
#         "${MI_AKS}" \
#         "Managed Identity Operator" \
#         "$(az identity show --name ${MI_AKS} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --subscription ${AZ_SUBSCRIPTION_ID} --query id --output tsv 2>/dev/null)"

#     # Kubelet identity: https://docs.microsoft.com/en-us/azure/aks/use-managed-identity#bring-your-own-kubelet-mi
#     create_managed_identity "${MI_AKSKUBELET}"
#     create_role_assignment_for_identity \
#         "${MI_AKSKUBELET}" \
#         "AcrPull" \
#         "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_COMMON}/providers/Microsoft.ContainerRegistry/registries/${AZ_RESOURCE_CONTAINER_REGISTRY}"
# }


# function update_acr_whitelist() {
#     #######################################################################################
#     ### Add ACR network rule
#     ###

#     printf "Whitelisting cluster egress IP(s) in ACR network rules\n"
#     printf "Retrieving egress IP range for %s cluster...\n" "${CLUSTER_NAME}"
#     local egress_ip_range=$(get_cluster_outbound_ip ${MIGRATION_STRATEGY} ${CLUSTER_NAME} ${AZ_SUBSCRIPTION_ID} ${AZ_IPPRE_OUTBOUND_NAME} ${AZ_RESOURCE_GROUP_COMMON})
#     printf "Retrieved IP range %s.\n" "${egress_ip_range}"
#     # Update ACR IP whitelist with cluster egress IP(s)
#     printf "\n"
#     printf "%s► Execute %s%s\n" "${grn}" "$WHITELIST_IP_IN_ACR_SCRIPT" "${normal}"
#     (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" IP_MASK=${egress_ip_range} IP_LOCATION=$CLUSTER_NAME ACTION=add $WHITELIST_IP_IN_ACR_SCRIPT)
#     wait # wait for subshell to finish
#     printf "\n"
# }

#######################################################################################
### MAIN
###

update_app_registrations
# create_resource_groups
create_common_resources
create_outbound_public_ip_prefix
create_inbound_public_ip_prefix
create_acr
# update_acr_whitelist
create_base_system_users_and_store_credentials
create_servicenow_proxy_server_app_registration
update_app_registration
# create_managed_identities_and_role_assignments
set_permissions_on_acr
create_acr_tasks


#######################################################################################
### END
###

echo ""
echo "Azure DNS Zone delegation is a manual step."
echo "See how to in https://github.com/equinor/radix-private/blob/master/docs/infrastructure/dns.md#how-to-delegate-from-prod-to-dev-or-playground"

echo ""
echo "Bootstrap of base infrastructure done!"
