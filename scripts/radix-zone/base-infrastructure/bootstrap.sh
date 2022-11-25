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

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    printf "\n\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}
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

printf "\n"
printf "\nBootstrap of base infrastructure will use the following configuration:"
printf "\n"
printf "\n   > WHERE:"
printf "\n   ------------------------------------------------------------------"
printf "\n   -  RADIX_ZONE                                  : $RADIX_ZONE"
printf "\n   -  AZ_RADIX_ZONE_LOCATION                      : $AZ_RADIX_ZONE_LOCATION"
printf "\n   -  RADIX_ENVIRONMENT                           : $RADIX_ENVIRONMENT"
printf "\n"
printf "\n   > WHAT:"
printf "\n   -------------------------------------------------------------------"
printf "\n   -  AZ_RESOURCE_GROUP_CLUSTERS                  : $AZ_RESOURCE_GROUP_CLUSTERS"
printf "\n   -  AZ_RESOURCE_GROUP_COMMON                    : $AZ_RESOURCE_GROUP_COMMON"
printf "\n   -  AZ_RESOURCE_GROUP_MONITORING                : $AZ_RESOURCE_GROUP_MONITORING"
printf "\n"
printf "\n   -  AZ_RESOURCE_KEYVAULT                        : $AZ_RESOURCE_KEYVAULT"
printf "\n   -  AZ_IPPRE_OUTBOUND_NAME                      : $AZ_IPPRE_OUTBOUND_NAME"
printf "\n   -  AZ_IPPRE_OUTBOUND_IP_PREFIX                 : $AZ_IPPRE_OUTBOUND_IP_PREFIX"
printf "\n   -  AZ_IPPRE_OUTBOUND_LENGTH                    : $AZ_IPPRE_OUTBOUND_LENGTH"
printf "\n   -  AZ_IPPRE_INBOUND_NAME                       : $AZ_IPPRE_INBOUND_NAME"
printf "\n   -  AZ_IPPRE_INBOUND_IP_PREFIX                  : $AZ_IPPRE_INBOUND_IP_PREFIX"
printf "\n   -  AZ_IPPRE_INBOUND_LENGTH                     : $AZ_IPPRE_INBOUND_LENGTH"
printf "\n   -  AZ_RESOURCE_CONTAINER_REGISTRY              : $AZ_RESOURCE_CONTAINER_REGISTRY"
printf "\n   -  AZ_RESOURCE_DNS                             : $AZ_RESOURCE_DNS"
printf "\n"
printf "\n   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER    : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER"
printf "\n   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD      : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD"
printf "\n   -  AZ_SYSTEM_USER_DNS                          : $AZ_SYSTEM_USER_DNS"
printf "\n   -  APP_REGISTRATION_GRAFANA                    : $APP_REGISTRATION_GRAFANA"
printf "\n   -  APP_REGISTRATION_CERT_MANAGER               : $APP_REGISTRATION_CERT_MANAGER"
printf "\n   -  APP_REGISTRATION_VELERO                     : $APP_REGISTRATION_VELERO"
printf "\n"
printf "\n   -  MI_AKS                                      : $MI_AKS"
printf "\n   -  MI_AKSKUBELET                               : $MI_AKSKUBELET"
printf "\n"
printf "\n   > WHO:"
printf "\n   -------------------------------------------------------------------"
printf "\n   -  AZ_SUBSCRIPTION                             : $(az account show --query name -otsv)"
printf "\n   -  AZ_USER                                     : $(az account show --query user.name -o tsv)"
printf "\n"

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
### App registration permissions
###

function update_app_registrations(){
    update_app_registration_permissions="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../update_app_registration_permissions.sh"
    if [[ -f "$update_app_registration_permissions" ]]; then
        echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$update_app_registration_permissions is invalid, the file does not exist." >&2
        exit 1
    else
        source "$update_app_registration_permissions"
    fi
}

#######################################################################################
### Resource groups
###

function create_resource_groups() {
    printf "Creating all resource groups..."
    az group create --location "${AZ_RADIX_ZONE_LOCATION}" --name "${AZ_RESOURCE_GROUP_CLUSTERS}" --subscription "${AZ_SUBSCRIPTION_ID}" --output none
    az group create --location "${AZ_RADIX_ZONE_LOCATION}" --name "${AZ_RESOURCE_GROUP_COMMON}"--subscription "${AZ_SUBSCRIPTION_ID}" --output none
    az group create --location "${AZ_RADIX_ZONE_LOCATION}" --name "${AZ_RESOURCE_GROUP_MONITORING}" --subscription "${AZ_SUBSCRIPTION_ID}" --output none
    az group create --location "${AZ_RADIX_ZONE_LOCATION}" --name "${AZ_RESOURCE_GROUP_LOGS}" --subscription "${AZ_SUBSCRIPTION_ID}" --output none
    printf "...Done\n"
}

#######################################################################################
### Common resources
###

function create_common_resources() {
    printf "Creating key vault: ${AZ_RESOURCE_KEYVAULT}...\n"
    az keyvault create \
        --name "${AZ_RESOURCE_KEYVAULT}" \
        --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --enable-purge-protection \
        --output none
    printf "...Done\n"

    printf "Set access policy for group \"Radix Platform Operators\" in key vault: ${AZ_RESOURCE_KEYVAULT}...\n"
    az keyvault set-policy \
        --object-id "$(az ad group show --group "Radix Platform Operators" --query objectId --output tsv --only-show-errors)" \
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

    printf "Creating Azure DNS: ${AZ_RESOURCE_DNS}\n"
    az network dns zone create --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --name "${AZ_RESOURCE_DNS}" --subscription "${AZ_SUBSCRIPTION_ID}" --output none
    printf "...Done\n"
    # DNS CAA
    if [ "$RADIX_ENVIRONMENT" = "prod" ]; then
        printf "Adding CAA records..."
        az network dns record-set caa add-record --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --zone-name "${AZ_RESOURCE_DNS}" --subscription "${AZ_SUBSCRIPTION_ID}" --record-set-name @ --flags 0 --tag "issue" --value "letsencrypt.org" --output none
        az network dns record-set caa add-record --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --zone-name "${AZ_RESOURCE_DNS}" --subscription "${AZ_SUBSCRIPTION_ID}" --record-set-name @ --flags 0 --tag "issue" --value "digicert.com" --output none
        az network dns record-set caa add-record --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --zone-name "${AZ_RESOURCE_DNS}" --subscription "${AZ_SUBSCRIPTION_ID}" --record-set-name @ --flags 0 --tag "issue" --value "godaddy.com" --output none
        printf "...Done\n"
    fi
    ../private-endpoint-infrastructure/bootstrap.sh
}

function create_outbound_public_ip_prefix() {
    # Create public ip prefixes
    if [[ -n $AZ_IPPRE_OUTBOUND_NAME ]]; then
        if [[ -z $(az network public-ip prefix show --name "${AZ_IPPRE_OUTBOUND_NAME}" --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --subscription "${AZ_SUBSCRIPTION_ID}" --query "name" -otsv 2>/dev/null) ]]; then
            printf "Public IP Prefix ${AZ_IPPRE_OUTBOUND_NAME} does not exist.\n"
            if [[ $USER_PROMPT == true ]]; then
                while true; do
                    read -p "Create Public IP Prefix: ${AZ_IPPRE_OUTBOUND_NAME}? (Y/n) " yn
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
                printf "Creating Public IP Prefix: ${AZ_IPPRE_OUTBOUND_NAME}...\n"
                az network public-ip prefix create \
                    --length "${AZ_IPPRE_OUTBOUND_LENGTH}" \
                    --name "${AZ_IPPRE_OUTBOUND_NAME}" \
                    --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
                    --subscription "${AZ_SUBSCRIPTION_ID}" \
                    --output none
                printf "...Done.\n"
            fi
        else
            printf "Public IP Prefix ${AZ_IPPRE_OUTBOUND_NAME} already exists."
        fi
        # Create IPs
        echo "Creating IPs in Public IP Prefix ${AZ_IPPRE_OUTBOUND_NAME}..."
        IPPRE_OUTBOUND_IP_NUMBER=$(az network public-ip prefix show \
            --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
            --name ${AZ_IPPRE_OUTBOUND_NAME} \
            --subscription ${AZ_SUBSCRIPTION_ID} \
            --query publicIpAddresses |
            jq -r .[].id |
            wc -l |
            sed 's/^ *//g')
        while true; do
            # Get current number of IPs, add trailing 0s and increment by 1
            IPPRE_OUTBOUND_IP_NUMBER=$(printf %03d $(($IPPRE_OUTBOUND_IP_NUMBER + 1)))
            IP_NAME="${AZ_IPPRE_OUTBOUND_IP_PREFIX}-${IPPRE_OUTBOUND_IP_NUMBER}"
            if [[ $(az network public-ip create \
                --public-ip-prefix /subscriptions/$AZ_SUBSCRIPTION_ID/resourcegroups/$AZ_RESOURCE_GROUP_COMMON/providers/microsoft.network/publicipprefixes/$AZ_IPPRE_OUTBOUND_NAME \
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
                    read -p "Create Public IP Prefix: ${AZ_IPPRE_INBOUND_NAME}? (Y/n) " yn
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
                printf "Creating Public IP Prefix: ${AZ_IPPRE_INBOUND_NAME}...\n"
                az network public-ip prefix create \
                    --length "${AZ_IPPRE_INBOUND_LENGTH}" \
                    --name "${AZ_IPPRE_INBOUND_NAME}" \
                    --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
                    --subscription "${AZ_SUBSCRIPTION_ID}" \
                    --output none
                printf "...Done.\n"
            fi
        else
            printf "Public IP Prefix ${AZ_IPPRE_INBOUND_NAME} already exists."
        fi
        # Create IPs
        echo "Creating IPs in Public IP Prefix ${AZ_IPPRE_INBOUND_NAME}..."
        IPPRE_INBOUND_IP_NUMBER=$(az network public-ip prefix show \
            --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
            --name ${AZ_IPPRE_INBOUND_NAME} \
            --subscription ${AZ_SUBSCRIPTION_ID} \
            --query publicIpAddresses |
            jq -r .[].id |
            wc -l |
            sed 's/^ *//g')
        while true; do
            # Get current number of IPs, add trailing 0s and increment by 1
            IPPRE_INBOUND_IP_NUMBER=$(printf %03d $(($IPPRE_INBOUND_IP_NUMBER + 1)))
            IP_NAME="${AZ_IPPRE_INBOUND_IP_PREFIX}-${IPPRE_INBOUND_IP_NUMBER}"
            if [[ $(az network public-ip create \
                --public-ip-prefix /subscriptions/$AZ_SUBSCRIPTION_ID/resourcegroups/$AZ_RESOURCE_GROUP_COMMON/providers/microsoft.network/publicipprefixes/$AZ_IPPRE_INBOUND_NAME \
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


function set_permissions_on_dns() {
    local scope
    local id
    local dns # Optional input 1

    if [ -n "$1" ]; then
        dns="$1"
    else
        dns="$AZ_RESOURCE_DNS"
    fi

    if [ "$RADIX_ENVIRONMENT" = "classic" ]; then
        # Use Managed Identity.
        # https://cert-manager.io/docs/configuration/acme/dns01/azuredns/#managed-identity-using-aad-pod-identities

        printf "Azure dns zone: Setting permissions for \"${AZ_MANAGED_IDENTITY_NAME}\" on \"${dns}\"..."

        # Choose a unique Identity name and existing resource group to create identity in.
        IDENTITY="$(az identity show --name $AZ_MANAGED_IDENTITY_NAME --resource-group $AZ_RESOURCE_GROUP_CLUSTERS --output json)"
        # Gets principalId to use for role assignment
        PRINCIPAL_ID=$(echo $IDENTITY | jq -r '.principalId')
        # Get existing DNS Zone Id
        ZONE_ID=$(az network dns zone show --name ${dns} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --query "id" -o tsv)
        # Create role assignment
        az role assignment create --assignee $PRINCIPAL_ID --role "DNS Zone Contributor" --scope $ZONE_ID
        printf "...Done\n"
    else
        # Use service principle.

        scope="$(az network dns zone show --name ${dns} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --query "id" --output tsv)"

        # Grant 'DNS Zone Contributor' permissions to a specific zone
        # https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#dns-zone-contributor
        printf "Azure dns zone: Setting permissions for \"${AZ_SYSTEM_USER_DNS}\" on \"${dns}\"..."
        id="$(az ad sp list --display-name ${AZ_SYSTEM_USER_DNS} --query [].appId --output tsv)"
        az role assignment create --assignee "${id}" --role "DNS Zone Contributor" --scope "${scope}" --output none
        printf "...Done\n"
    fi
}

function create_dns_role_definition_for_cert_manager() {
    # Create DNS TXT Contributor role to be used by Cert Manager
    CUSTOM_DNS_ROLE_JSON="cert-mananger-custom-dns-role.json"
    test -f "$CUSTOM_DNS_ROLE_JSON" && rm "$CUSTOM_DNS_ROLE_JSON"
    cat <<EOF >>${CUSTOM_DNS_ROLE_JSON}
    {
        "Name": "DNS TXT Contributor",
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
    ROLE_DEFINITION=$(az role definition list --name "DNS TXT Contributor" --query [].assignableScopes[] --output tsv)
    if [[ -z ${ROLE_DEFINITION} ]]; then
        printf "Creating DNS TXT Contributor role definition..."
        az role definition create --role-definition "$CUSTOM_DNS_ROLE_JSON" 2>/dev/null
        rm "$CUSTOM_DNS_ROLE_JSON"
        while [ -z "$(az role definition list --query "[?roleName=='$ROLENAME'].name" -otsv)" ]; do
            sleep 5
            printf "."
        done
        printf "...Done.\n"
    elif [[ ! ${ROLE_DEFINITION[@]} =~ ${AZ_SUBSCRIPTION_ID} ]]; then
        echo "ERROR: Role definition exists, but subscription ${AZ_SUBSCRIPTION_ID} is not an assignable scope. This script does not update it, so it must be done manually." >&2
        return
    else
        echo "DNS TXT Contributor role definition exists."
    fi

    printf "Creating role assignment..."
    az role assignment create \
        --assignee "$APP_ID" \
        --role "$ROLENAME" \
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
    create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_DNS" "Can make changes in the DNS zone"
    create_service_principal_and_store_credentials "$APP_REGISTRATION_GRAFANA" "Grafana OAuth"
    create_service_principal_and_store_credentials "$APP_REGISTRATION_CERT_MANAGER" "Cert-Manager"
    create_service_principal_and_store_credentials "$APP_REGISTRATION_VELERO" "Used by Velero to access Azure resources"
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
function create_managed_identities_and_role_assignments() {
    # Control plane managed identity: https://docs.microsoft.com/en-us/azure/aks/use-managed-identity#bring-your-own-control-plane-mi
    create_managed_identity "${MI_AKS}"
    create_role_assignment_for_identity \
        "${MI_AKS}" \
        "Managed Identity Operator" \
        "$(az identity show --name ${MI_AKS} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --subscription ${AZ_SUBSCRIPTION_ID} --query id 2>/dev/null)"

    # Kubelet identity: https://docs.microsoft.com/en-us/azure/aks/use-managed-identity#bring-your-own-kubelet-mi
    create_managed_identity "${MI_AKSKUBELET}"
    create_role_assignment_for_identity \
        "${MI_AKSKUBELET}" \
        "AcrPull" \
        "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_COMMON}/providers/Microsoft.ContainerRegistry/registries/${AZ_RESOURCE_CONTAINER_REGISTRY}"
}

#######################################################################################
### Log analytics workspace
###
function create_log_analytics_workspace() {
    printf "Creating log-analytics workspace..."
    az monitor log-analytics workspace create \
        --workspace-name "${AZ_RESOURCE_LOG_ANALYTICS_WORKSPACE}" \
        --resource-group "${AZ_RESOURCE_GROUP_LOGS}" \
        --location "${AZ_RADIX_ZONE_LOCATION}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --output none \
        --only-show-errors
    printf "...Done\n"
}

#######################################################################################
### Create storage account for SQL logs
###

function create_sql_logs_storageaccount() {
    SQL_LOGS_STORAGEACCOUNT_EXIST=$(az storage account list \
        --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
        --subscription "$AZ_SUBSCRIPTION_ID" \
        --query "[?name=='$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS'].name" \
        --output tsv)

    if [ ! "$SQL_LOGS_STORAGEACCOUNT_EXIST" ]; then
        printf "%s does not exists.\n" "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS"

        printf "    Creating storage account %s..." "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS"
        az storage account create \
            --name "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS" \
            --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
            --location "$AZ_RADIX_ZONE_LOCATION" \
            --subscription "$AZ_SUBSCRIPTION_ID" \
            --only-show-errors
            --min-tls-version "${AZ_STORAGEACCOUNT_MIN_TLS_VERSION}" \
            --sku "${AZ_STORAGEACCOUNT_SKU}" \
            --kind "${AZ_STORAGEACCOUNT_KIND}" \
            --access-tier "${AZ_STORAGEACCOUNT_TIER}"
        printf "Done.\n"
    else
        printf "    Storage account exists...skipping\n"
    fi

    LIFECYCLE=7
    RULE_NAME=sql-rule

    MANAGEMENT_POLICY_EXIST=$(az storage account management-policy show \
        --account-name "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS" \
        --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
        --query "policy.rules | [?name=='$RULE_NAME']".name \
        --subscription "$AZ_SUBSCRIPTION_ID" \
        --output tsv)

    POLICY_JSON="$(
        cat <<END
{
  "rules": [
      {
          "enabled": "true",
          "name": "$RULE_NAME",
          "type": "Lifecycle",
          "definition": {
              "actions": {
                  "version": {
                      "delete": {
                          "daysAfterCreationGreaterThan": "$LIFECYCLE"
                      }
                  },
              },
              "filters": {
                  "blobTypes": [
                      "blockBlob"
                  ],
              }
          }
      }
  ]
}
END
    )"

    if [ ! "$MANAGEMENT_POLICY_EXIST" ]; then
        printf "Storage account %s is missing policy\n" "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS"

        if az storage account management-policy create \
            --account-name "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS" \
            --policy "$(echo "$POLICY_JSON")" \
            --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
            --subscription "$AZ_SUBSCRIPTION_ID" \
            --only-show-errors; then
            printf "Successfully created policy for %s\n" "$AZ_RESOURCE_STORAGEACCOUNT_SQL_LOGS"
        fi
    else
        printf "    Storage account has policy...skipping\n"
    fi

    printf "Done.\n"
}

function update_acr_whitelist() {
    #######################################################################################
    ### Add ACR network rule
    ###

    printf "Whitelisting cluster egress IP(s) in ACR network rules\n"
    printf "Retrieving egress IP range for ${CLUSTER_NAME} cluster...\n"
    local egress_ip_range=$(get_cluster_outbound_ip ${MIGRATION_STRATEGY} ${CLUSTER_NAME} ${AZ_SUBSCRIPTION_ID} ${AZ_IPPRE_OUTBOUND_NAME} ${AZ_RESOURCE_GROUP_COMMON})
    printf "Retrieved IP range ${egress_ip_range}.\n"
    # Update ACR IP whitelist with cluster egress IP(s)
    printf "\n"
    printf "%s► Execute %s%s\n" "${grn}" "$WHITELIST_IP_IN_ACR_SCRIPT" "${normal}"
    (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" IP_MASK=${egress_ip_range} IP_LOCATION=$CLUSTER_NAME ACTION=add $WHITELIST_IP_IN_ACR_SCRIPT)
    wait # wait for subshell to finish
    printf "\n"
}

#######################################################################################
### MAIN
###

update_app_registrations
create_resource_groups
create_common_resources
create_outbound_public_ip_prefix
create_inbound_public_ip_prefix
create_acr
update_acr_whitelist
create_base_system_users_and_store_credentials
create_servicenow_proxy_server_app_registration
update_app_registration
create_managed_identities_and_role_assignments
set_permissions_on_acr
create_acr_tasks
set_permissions_on_dns
create_dns_role_definition_for_cert_manager
create_log_analytics_workspace
create_sql_logs_storageaccount

#######################################################################################
### END
###

echo ""
echo "Azure DNS Zone delegation is a manual step."
echo "See how to in https://github.com/equinor/radix-private/blob/master/docs/infrastructure/dns.md#how-to-delegate-from-prod-to-dev-or-playground"

echo ""
echo "Bootstrap of base infrastructure done!"
