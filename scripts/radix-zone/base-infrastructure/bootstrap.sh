#!/bin/bash

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
hash az 2> /dev/null || { printf "\n\nError: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"


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

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Load dependencies
LIB_SERVICE_PRINCIPAL_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../service-principals-and-aad-apps/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
   echo "The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
   exit 1
else
   source "$LIB_SERVICE_PRINCIPAL_PATH"
fi
AD_APP_MANIFEST_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/manifest-server.json"
if [[ ! -f "$AD_APP_MANIFEST_PATH" ]]; then
   echo "The dependency AD_APP_MANIFEST_PATH=$AD_APP_MANIFEST_PATH is invalid, the file does not exist." >&2
   exit 1
fi


#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION" >/dev/null
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
printf "\n   -  AZ_RESOURCE_CONTAINER_REGISTRY              : $AZ_RESOURCE_CONTAINER_REGISTRY"
printf "\n   -  AZ_RESOURCE_DNS                             : $AZ_RESOURCE_DNS"
printf "\n   -  AZ_RESOURCE_KEYVAULT                        : $AZ_RESOURCE_KEYVAULT"
printf "\n"
printf "\n   -  AZ_RESOURCE_AAD_SERVER                      : $AZ_RESOURCE_AAD_SERVER"
printf "\n   -  AZ_RESOURCE_AAD_CLIENT                      : $AZ_RESOURCE_AAD_CLIENT"
printf "\n"
printf "\n   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER    : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER"
printf "\n   -  AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD      : $AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD"
printf "\n   -  AZ_SYSTEM_USER_CLUSTER                      : $AZ_SYSTEM_USER_CLUSTER"
printf "\n   -  AZ_SYSTEM_USER_DNS                          : $AZ_SYSTEM_USER_DNS"
printf "\n"
printf "\n   > WHO:"
printf "\n   -------------------------------------------------------------------"
printf "\n   -  AZ_SUBSCRIPTION                             : $AZ_SUBSCRIPTION"
printf "\n   -  AZ_USER                                     : $(az account show --query user.name -o tsv)"
printf "\n"

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


#######################################################################################
### Resource groups
###

function create_resource_groups() {
    local groupName

    printf "\nCreating all resource groups..."
    az group create --location "${AZ_INFRASTRUCTURE_REGION}" --name "${AZ_RESOURCE_GROUP_CLUSTERS}" --output none
    az group create --location "${AZ_INFRASTRUCTURE_REGION}" --name "${AZ_RESOURCE_GROUP_COMMON}" --output none
    az group create --location "${AZ_INFRASTRUCTURE_REGION}" --name "${AZ_RESOURCE_GROUP_MONITORING}" --output none
    printf "...Done\n"
}


#######################################################################################
### Common resources
###

function create_common_resources() {    
    printf "\nCreating keyvault: ${AZ_RESOURCE_KEYVAULT}..."
    az keyvault create --name "${AZ_RESOURCE_KEYVAULT}" --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --output none
    printf "...Done\n"
           
    printf "\nCreating Azure Container Registry: ${AZ_RESOURCE_CONTAINER_REGISTRY}..."
    az acr create --name "${AZ_RESOURCE_CONTAINER_REGISTRY}" --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --sku "Standard" --output none
    printf "...Done\n"
   
    printf "\nCreating Azure DNS: ${AZ_RESOURCE_DNS}"
    az network dns zone create -g "${AZ_RESOURCE_GROUP_COMMON}" -n "${AZ_RESOURCE_DNS}" --output none
    printf "...Done\n"
    # DNS CAA    
    if [ "$RADIX_ENVIRONMENT" = "prod" ]; then
        printf "\nAdding CAA records..."
        az network dns record-set caa add-record -g "${AZ_RESOURCE_GROUP_COMMON}" --zone-name "${AZ_RESOURCE_DNS}" --record-set-name @ --flags 0 --tag "issue" --value "letsencrypt.org"
        az network dns record-set caa add-record -g "${AZ_RESOURCE_GROUP_COMMON}" --zone-name "${AZ_RESOURCE_DNS}" --record-set-name @ --flags 0 --tag "issue" --value "digicert.com"
        az network dns record-set caa add-record -g "${AZ_RESOURCE_GROUP_COMMON}" --zone-name "${AZ_RESOURCE_DNS}" --record-set-name @ --flags 0 --tag "issue" --value "godaddy.com"
        printf "...Done\n"
    fi
}

function set_permissions_on_acr() {
    local scope
    scope="$(az acr show --name ${AZ_RESOURCE_CONTAINER_REGISTRY} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --query "id" --output tsv)"

    # Available roles
    # https://github.com/Azure/acr/blob/master/docs/roles-and-permissions.md
    # Note that to be able to use "az acr build" you have to have the role "Contributor".

    local id
    printf "\nContainer registry: Setting permissions for \"${AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER}\"..."
    id="$(az ad sp show --id http://${AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER} --query appId --output tsv)"
    # Delete any existing roles
    az role assignment delete --assignee "${id}" --scope "${scope}" --output none
    # Configure new roles
    az role assignment create --assignee "${id}" --role AcrPull --scope "${scope}" --output none
    printf "...Done\n"

    printf "\nContainer registry: Setting permissions for \"${AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD}\"..."
    id="$(az ad sp show --id http://${AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD} --query appId --output tsv)"
    # Delete any existing roles
    az role assignment delete --assignee "${id}" --scope "${scope}" --output none
    # Configure new roles
    az role assignment create --assignee "${id}" --role Contributor --scope "${scope}" --output none
    printf "...Done\n"

    printf "\nContainer registry: Setting permissions for \"${AZ_SYSTEM_USER_CLUSTER}\"..."
    id="$(az ad sp show --id http://${AZ_SYSTEM_USER_CLUSTER} --query appId --output tsv)"
    # Delete any existing roles
    az role assignment delete --assignee "${id}" --scope "${scope}" --output none
    # Configure new roles
    az role assignment create --assignee "${id}" --role AcrPull --scope "${scope}" --output none
    printf "...Done\n"
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

    scope="$(az network dns zone show --name ${dns} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --query "id" --output tsv)"

    # Grant 'DNS Zone Contributor' permissions to a specific zone
    # https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#dns-zone-contributor
    printf "\nAzure dns zone: Setting permissions for \"${AZ_SYSTEM_USER_DNS}\" on \"${dns}\"..."
    id="$(az ad sp show --id http://${AZ_SYSTEM_USER_DNS} --query appId --output tsv)"
    az role assignment create --assignee "${id}" --role "DNS Zone Contributor" --scope "${scope}" --output none
    printf "...Done\n"
}


#######################################################################################
### System users
###

function create_base_system_users_and_store_credentials(){
    create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_CONTAINER_REGISTRY_READER" "Service principal that provide read-only access to container registry"
    create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_CONTAINER_REGISTRY_CICD" "Service principal that provide push, pull, build in container registry"
    create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_CLUSTER" "The AKS service principal"
    create_service_principal_and_store_credentials "$AZ_SYSTEM_USER_DNS" "Can make changes in the DNS zone"
}


#######################################################################################
### AAD apps for k8s RBAC integration
###

function create_az_ad_server_app() {
    # This function will create the AAD server app and related service principal,
    # set permissions on the app,
    # and store the app credentials in the keyvault.
    local rbac_server_app_name="${AZ_RESOURCE_AAD_SERVER}"
    local RBAC_SERVER_APP_URL="http://${rbac_server_app_name}"
    local RBAC_SERVER_APP_SECRET="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)" # Temporary secret, we will reset the credentials when we create the sp for this app.

    # Create the Azure Active Directory server application
    echo "Creating AAD server application \"${rbac_server_app_name}\"..."
    az ad app create --display-name "${rbac_server_app_name}" \
    --password "${RBAC_SERVER_APP_SECRET}" \
    --identifier-uris "${RBAC_SERVER_APP_URL}" \
    --reply-urls "${RBAC_SERVER_APP_URL}" \
    --homepage "${RBAC_SERVER_APP_URL}" \
    --required-resource-accesses @"$AD_APP_MANIFEST_PATH"

    # Update the application claims
    local RBAC_SERVER_APP_ID="$(az ad app list --identifier-uri ${RBAC_SERVER_APP_URL} --query [].appId -o tsv)"    
    az ad app update --id "${RBAC_SERVER_APP_ID}" --set groupMembershipClaims=All

    # Create service principal for the server application
    echo "Creating service principal for server application..."
    az ad sp create --id "${RBAC_SERVER_APP_ID}"
    # Reset password to something azure will give us
    RBAC_SERVER_APP_SECRET="$(az ad app credential reset --id ${RBAC_SERVER_APP_ID} --query password --output tsv)"

    # Grant permissions to server application
    echo "Granting permissions to the server application..."
    local RESOURCE_API_ID
    local RBAC_SERVER_APP_RESOURCES_API_IDS="$(az ad app permission list --id ${RBAC_SERVER_APP_ID} --query [].resourceAppId --out tsv | xargs echo)"
    for RESOURCE_API_ID in $RBAC_SERVER_APP_RESOURCES_API_IDS;
    do
        if [ "$RESOURCE_API_ID" == "00000002-0000-0000-c000-000000000000" ]
        then
            az ad app permission grant --api "$RESOURCE_API_ID" --id "$RBAC_SERVER_APP_ID" --scope "User.Read"
            echo "Granted User.Read"
        elif [ "$RESOURCE_API_ID" == "00000003-0000-0000-c000-000000000000" ]
        then
            az ad app permission grant --api "$RESOURCE_API_ID" --id "$RBAC_SERVER_APP_ID" --scope "Directory.Read.All"
            echo "Granted Directory.Read.All"
        else
            # echo "RESOURCE_API_ID=$RESOURCE_API_ID"
            az ad app permission grant --api "$RESOURCE_API_ID" --id "$RBAC_SERVER_APP_ID" --scope "user_impersonation"
            echo "Granted user_impersonation"
        fi
    done
    
    # Store app credentials in keyvault
    update_service_principal_credentials_in_az_keyvault "${rbac_server_app_name}" "${RBAC_SERVER_APP_ID}" "${RBAC_SERVER_APP_SECRET}" "AZ AD server app to enable AKS rbac. Display name is \"${rbac_server_app_name}\"."
    
    # Notify user about manual steps to make permissions usable
    echo -e ""
    echo -e "The Azure Active Directory application \"${rbac_server_app_name}\" has been created."
    echo -e "You need to ask an Azure AD Administrator to go the Azure portal an click the \"Grant permissions\" button for this app."
    echo -e ""
}

function create_az_ad_client_app() {
    local rbac_client_app_name="${AZ_RESOURCE_AAD_CLIENT}"
    local RBAC_CLIENT_APP_URL="http://${rbac_client_app_name}"

    local RBAC_SERVER_CREDENTIALS="KEYVAULT"
    local RBAC_SERVER_APP_ID="KEYVAULT"
    local RBAC_SERVER_APP_OAUTH2PERMISSIONS_ID="LOOKUP"
    local RBAC_SERVER_APP_SECRET="KEYVAULT"
    local CLIENT_MANIFEST_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/manifest-client.json"

    echo "Creating AAD client application \"${rbac_client_app_name}\"..."

    # Get AAD server info from keyvault and use it to lookup oauth2 permisssion id
    RBAC_SERVER_CREDENTIALS="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name ${AZ_RESOURCE_AAD_SERVER} | jq -r .value)"
    RBAC_SERVER_APP_ID="$(echo $RBAC_SERVER_CREDENTIALS | jq -r .id)"
    RBAC_SERVER_APP_SECRET="$(echo $RBAC_SERVER_CREDENTIALS | jq -r .password)"
    RBAC_SERVER_APP_OAUTH2PERMISSIONS_ID="$(az ad app show --id ${RBAC_SERVER_APP_ID} --query oauth2Permissions[0].id -o tsv)"

    # Create client application
    # First we need a manifest
    cat > "$CLIENT_MANIFEST_PATH" << EOF
[
    {
    "resourceAppId": "${RBAC_SERVER_APP_ID}",
    "resourceAccess": [
        {
        "id": "${RBAC_SERVER_APP_OAUTH2PERMISSIONS_ID}",
        "type": "Scope"
        }
    ]
    }
]
EOF

    # Then we create the client application and provide the manifest
    az ad app create --display-name "${rbac_client_app_name}" \
        --native-app \
        --reply-urls "${RBAC_CLIENT_APP_URL}" \
        --homepage "${RBAC_CLIENT_APP_URL}" \
        --required-resource-accesses @manifest-client.json    
    
    # Finally remove manifest-client.json file as it is no longer needed
    rm ./manifest-client.json  

    # To be able to use the client app then we need a service principal for it    
    # Create service principal for the client application
    echo "Creating service principal for AAD client application..."
    local RBAC_CLIENT_APP_ID="$(az ad app list --display-name ${rbac_client_app_name} --query [].appId -o tsv)"
    az ad sp create --id "${RBAC_CLIENT_APP_ID}"    

    # Grant permissions to server application
    echo "Granting permissions to the AAD client application..."
    local RESOURCE_API_ID
    local RBAC_CLIENT_APP_RESOURCES_API_IDS="$(az ad app permission list --id $RBAC_CLIENT_APP_ID --query [].resourceAppId --out tsv | xargs echo)"
    for RESOURCE_API_ID in $RBAC_CLIENT_APP_RESOURCES_API_IDS;
    do
        az ad app permission grant --api $RESOURCE_API_ID --id $RBAC_CLIENT_APP_ID
    done

    # Store the client app credentials in the keyvault
    update_service_principal_credentials_in_az_keyvault "${rbac_client_app_name}" "${RBAC_CLIENT_APP_ID}" "native apps do not use secrets" "AZ AD client app to enable AKS authorization. Display name is \"${rbac_client_app_name}\"."    

    # Notify user about manual steps to make permissions usable
    echo -e ""
    echo -e "The Azure Active Directory application \"${rbac_client_app_name}\" has been created."
    echo -e "You need to ask an Azure AD Administrator to go the Azure portal an click the \"Grant permissions\" button for this app."
    echo -e ""
}


#######################################################################################
### MAIN
###

create_resource_groups
create_common_resources
create_base_system_users_and_store_credentials
set_permissions_on_acr
set_permissions_on_dns
create_az_ad_server_app
create_az_ad_client_app


#######################################################################################
### END
###

echo ""
echo "Azure DNS Zone delegation is a manual step."
echo "See how to in https://github.com/equinor/radix-private/blob/master/docs/infrastructure/dns.md#how-to-delegate-from-prod-to-dev-or-playground"

echo ""
echo "Bootstrap done!"