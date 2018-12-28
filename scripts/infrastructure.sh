#!/bin/bash

# PURPOSE
# Provision az infrastructure that will hold and support radix clusters.
# There are two main features which both have their own defined function
# - "install"
# - "destroy"
# The rest are support funcs for these two.

# USAGE
# See "show_help" func or simply run the script with no arguments.

# USEFUL INFO
# Built in roles for Azure resources
# https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
#
# AZ resource tags
# https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-using-tags
#
# AZ Service Principal
# https://docs.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest#az-ad-sp-create-for-rbac


########################################################################
# CONFIG VARS
########################################################################

RADIX_INFRASTRUCTURE_REGION="northeurope"
RADIX_INFRASTRUCTURE_SUBSCRIPTION="Omnia Radix Production" # "Omnia Radix Production" | "Omnia Radix Development"
RADIX_INFRASTRUCTURE_ENVIRONMENT="prod" # "prod" | "dev"

# Resource groups and resources
RADIX_RESOURCE_GROUP_CLUSTERS="clusters"
RADIX_RESOURCE_GROUP_COMMON="common"
RADIX_RESOURCE_GROUP_MONITORING="monitoring"
RADIX_RESOURCE_KEYVAULT="radix-vault-${RADIX_INFRASTRUCTURE_ENVIRONMENT}"
RADIX_RESOURCE_CONTAINER_REGISTRY="radix${RADIX_INFRASTRUCTURE_ENVIRONMENT}" # Note - ACR names cannot contain "-" due to reasons...
# Set dns name according to environment.
# It will default to production value.
RADIX_RESOURCE_DNS_SUFFIX="radix.equinor.com"
RADIX_RESOURCE_DNS="$RADIX_RESOURCE_DNS_SUFFIX"
if [ "$RADIX_INFRASTRUCTURE_ENVIRONMENT" != "prod" ]; then
    RADIX_RESOURCE_DNS="${RADIX_INFRASTRUCTURE_ENVIRONMENT}.${RADIX_RESOURCE_DNS_SUFFIX}"
fi

# Ad groups for resource management
RADIX_ADGROUP_CLUSTER="fg_radix_cluster_admin_${RADIX_INFRASTRUCTURE_ENVIRONMENT}"
RADIX_ADGROUP_COMMON="fg_radix_common_resource_admin_${RADIX_INFRASTRUCTURE_ENVIRONMENT}"
RADIX_ADGROUP_MONITORING="fg_radix_monitoring_admin_${RADIX_INFRASTRUCTURE_ENVIRONMENT}"

# All system users per environment
RADIX_SYSTEM_USER_CONTAINER_REGISTRY_READER="radix-cr-reader-${RADIX_INFRASTRUCTURE_ENVIRONMENT}"
RADIX_SYSTEM_USER_CONTAINER_REGISTRY_CICD="radix-cr-cicd-${RADIX_INFRASTRUCTURE_ENVIRONMENT}"
RADIX_SYSTEM_USER_CLUSTER="radix-cluster-${RADIX_INFRASTRUCTURE_ENVIRONMENT}"
RADIX_SYSTEM_USER_DNS="radix-dns-${RADIX_INFRASTRUCTURE_ENVIRONMENT}"

# APP VARS
__bin_dir_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # Now we now where the script is run from, and can later use this as base path when making references to other app files.

# STYLES
__style_end="\033[0m"
__style_yellow="\033[33m"
__style_green="\033[32m"


########################################################################
# UTILS
########################################################################

function echo_step(){
    echo -e ""
    echo -e "${__style_yellow}${1}${__style_end}"
}

function ask_user() {
    local question # Input 1, optional
    local moreInfo # Input 2, optional
    
    question="Do you want to continue?" # Default value
    if [ ! -z "$1" ]; then
        question="$1"
    fi
    moreInfo="$2"

    echo ""
    echo -e "${__style_yellow}${question}${__style_end}"
    if [ ! -z "${moreInfo}" ]; then
        echo -e "${moreInfo}"
    fi
    read -p "[Y]es or [N]o " -n 1 -r
    echo ""     
}

########################################################################
# AUTHENTICATION
########################################################################

function set_subscription() {
    az account set --subscription "$RADIX_INFRASTRUCTURE_SUBSCRIPTION"
}

########################################################################
# RESOURCE GROUPS AND RESOURCES
########################################################################


function provision_resource_groups() {
    local groupName

    echo_step "Creating all resource groups..."
    az group create --location "${RADIX_INFRASTRUCTURE_REGION}" --name "clusters"
    az group create --location "${RADIX_INFRASTRUCTURE_REGION}" --name "common"
    az group create --location "${RADIX_INFRASTRUCTURE_REGION}" --name "monitoring"
}


function provision_common_resources() {    
    # Keyvault
    echo_step "Creating keyvault: ${RADIX_RESOURCE_KEYVAULT}"
    az keyvault create --name "${RADIX_RESOURCE_KEYVAULT}" --resource-group "${RADIX_RESOURCE_GROUP_COMMON}"
           
    # Container registry
    # Note - ACR names cannot contain "-" due to reasons...
    echo_step "Creating Azure Container Registry: ${RADIX_RESOURCE_CONTAINER_REGISTRY}"
    az acr create --name "${RADIX_RESOURCE_CONTAINER_REGISTRY}" --resource-group "${RADIX_RESOURCE_GROUP_COMMON}" --sku "Standard"
   
    # DNS zone
    echo_step "Creating Azure DNS: ${RADIX_RESOURCE_DNS}"
    az network dns zone create -g "${RADIX_RESOURCE_GROUP_COMMON}" -n "${RADIX_RESOURCE_DNS}"   
    # DNS CAA    
    # if [ "$RADIX_INFRASTRUCTURE_ENVIRONMENT" = "prod" ]; then
    #     ask_user "Create CAA records?"
    #     if [[ "$REPLY" =~ ^[Yy]$ ]]
    #     then
    #       echo_step "Creating CAA records in ${RADIX_RESOURCE_DNS}"
    #       az network dns record-set caa add-record -g "${RADIX_RESOURCE_GROUP_COMMON}" --zone-name "${RADIX_RESOURCE_DNS}" --record-set-name @ --flags 0 --tag "issue" --value "letsencrypt.org"
    #       az network dns record-set caa add-record -g "${RADIX_RESOURCE_GROUP_COMMON}" --zone-name "${RADIX_RESOURCE_DNS}" --record-set-name @ --flags 0 --tag "issue" --value "digicert.com"
    #       az network dns record-set caa add-record -g "${RADIX_RESOURCE_GROUP_COMMON}" --zone-name "${RADIX_RESOURCE_DNS}" --record-set-name @ --flags 0 --tag "issue" --value "godaddy.com"  
    #     fi    
    # fi
}

function provision_monitoring_resources() {
    echo_step "Provison moniting resources"
    echo -e "These should be deployed from the monitoring project repo."
}



########################################################################
# SERVICE PRINCIPALS
########################################################################

function update_sp_in_keyvault() {
    local name              # Input 1
    local id                # Input 2
    local password          # Input 3
    local description       # Input 4, optional
    local tenantId
    local subscriptionId
    local tmp_file_path
    local template_path

    name="$1"
    id="$2"
    password="$3"
    description="$4"    
    tenantId="$(az ad sp show --id ${id} --query appOwnerTenantId --output tsv)"
    template_path="${__bin_dir_path}/service-principal.template.json"

    echo_step "Service principal: storing credentials in keyvault for ${name}"

    if [ ! -e "$template_path" ]; then
        echo "Error: sp json template not found"
        exit 1
    fi    

    # Use jq together with a credentials json template to ensure we end up with valid json, and then put the result into a tmp file which we will upload to the keyvault.
    tmp_file_path="${__bin_dir_path}/${name}.json"
    cat "$template_path" | jq -r \
    --arg name "${name}" \
    --arg id "${id}" \
    --arg password "${password}" \
    --arg description "${description}" \
    --arg tenantId "${tenantId}" \
    '.name=$name | .id=$id | .password=$password | .description=$description | .tenantId=$tenantId' > "$tmp_file_path"
    
    # show result
    cat "${tmp_file_path}"

    # Upload to keyvault
    az keyvault secret set --vault-name "${RADIX_RESOURCE_KEYVAULT}" -n "${name}" -f "${tmp_file_path}"

    # Clean up
    rm -rf "$tmp_file_path"    
}

function create_service_principal() {
    local name          # Input 1
    local description   # Input 2, optional
    local password
    local id

    name="$1"
    description="$2"

    echo_step "Service principal: creating \"${name}\""

    # Exit gracefully if the sp exist
    local testSP
    testSP="$(az ad sp show --id http://${name} --query appDisplayName --output tsv 2> /dev/null)"
    if [ ! -z "$testSP" ]; then
        echo -e "${name} exist, skipping."
        return
    fi

    password="$(az ad sp create-for-rbac --skip-assignment --name ${name} --query password --output tsv)"
    id="$(az ad sp show --id http://${name} --query appId --output tsv)"
    update_sp_in_keyvault "${name}" "${id}" "${password}" "${description}"
}

########################################################################
# AUTHORIZATION
########################################################################

function set_permission_on_resource_group() {
    local resourceGroupName # Input 1
    local adGroupName # Input 2    
    local roleName # Input 3
    local scope
    local adGroupId

    resourceGroupName="$1"
    adGroupName="$2"
    roleName="$3"

    adGroupId="$(az ad group show -g ${adGroupName} --query 'objectId' --out tsv)"
    scope="/subscriptions/$(az account show --query 'id' --out tsv)/resourceGroups/${resourceGroupName}"

    echo_step "Resource group: Setting permissions on \"${resourceGroupName}\" for \"${adGroupName}\"..."
    az role assignment create --assignee "$adGroupId" \
    --role "${roleName}" \
    --scope "${scope}"
}

function set_permissions_on_all_resource_groups() {
    set_permission_on_resource_group "${RADIX_RESOURCE_GROUP_CLUSTERS}" "${RADIX_ADGROUP_CLUSTER}" "contributor"
    set_permission_on_resource_group "${RADIX_RESOURCE_GROUP_COMMON}" "${RADIX_ADGROUP_COMMON}" "contributor"
    set_permission_on_resource_group "${RADIX_RESOURCE_GROUP_MONITORING}" "${RADIX_ADGROUP_MONITORING}" "contributor"
}

function set_permissions_on_keyvault() {
    local adGroupId
    
    echo -e "Keyvault: Setting default permissions for admins \"${RADIX_ADGROUP_COMMON}\"..."
    adGroupId="$(az ad group show -g ${RADIX_ADGROUP_COMMON} --query 'objectId' --out tsv)"
    # --name -n      [Required] : Name of the key vault.
    # --object-id               : A GUID that identifies the principal that will receive permissions.
    # --resource-group -g       : Proceed only if Key Vault belongs to the specified resource group.
    # --spn                     : Name of a service principal that will receive permissions.
    # --upn                     : Name of a user principal that will receive permissions.
    # --secret-permissions      : Space-separated list of secret permissions to assign.  Allowed
    #                             values: backup, delete, get, list, purge, recover, restore, set.
    az keyvault set-policy --name "${RADIX_RESOURCE_KEYVAULT}" --resource-group "${RADIX_RESOURCE_GROUP_COMMON}" --object-id "${adGroupId}" --secret-permissions list get set delete    
}

function set_permissions_on_acr() {
    local scope
    scope="$(az acr show --name ${RADIX_RESOURCE_CONTAINER_REGISTRY} --resource-group ${RADIX_RESOURCE_GROUP_COMMON} --query "id" --output tsv)"

    # Available roles
    # https://github.com/Azure/acr/blob/master/docs/roles-and-permissions.md
    # Note that to be able to use "az acr build" you have to have the role "Contributor".

    local id
    echo -e "Container registry: Setting permissions for \"${RADIX_SYSTEM_USER_CONTAINER_REGISTRY_READER}\"..."
    id="$(az ad sp show --id http://${RADIX_SYSTEM_USER_CONTAINER_REGISTRY_READER} --query appId --output tsv)"
    # Delete any existing roles
    az role assignment delete --assignee "${id}" --scope "${scope}"
    # Configure new roles
    az role assignment create --assignee "${id}" --role AcrPull --scope "${scope}"

    echo -e "Container registry: Setting permissions for \"${RADIX_SYSTEM_USER_CONTAINER_REGISTRY_CICD}\"..."
    id="$(az ad sp show --id http://${RADIX_SYSTEM_USER_CONTAINER_REGISTRY_CICD} --query appId --output tsv)"
    # Delete any existing roles
    az role assignment delete --assignee "${id}" --scope "${scope}"
    # Configure new roles
    az role assignment create --assignee "${id}" --role Contributor --scope "${scope}"

    echo -e "Container registry: Setting permissions for \"${RADIX_SYSTEM_USER_CLUSTER}\"..."
    id="$(az ad sp show --id http://${RADIX_SYSTEM_USER_CLUSTER} --query appId --output tsv)"
    # Delete any existing roles
    az role assignment delete --assignee "${id}" --scope "${scope}"
    # Configure new roles
    az role assignment create --assignee "${id}" --role AcrPush --scope "${scope}"
}

function set_permissions_on_dns() {
    local scope
    local id
    scope="$(az network dns zone show --name ${RADIX_RESOURCE_DNS} --resource-group ${RADIX_RESOURCE_GROUP_COMMON} --query "id" --output tsv)"

    # Grant 'DNS Zone Contributor' permissions to a specific zone
    # https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#dns-zone-contributor
    echo -e "Azure dns zone: Setting permissions for \"${RADIX_SYSTEM_USER_DNS}\" on \"${RADIX_RESOURCE_DNS}\"..."
    id="$(az ad sp show --id http://${RADIX_SYSTEM_USER_DNS} --query appId --output tsv)"
    az role assignment create --assignee "${id}" --role "DNS Zone Contributor" --scope "${scope}"
    
    # demo code
    #azure role assignment create --signInName <user email address> --roleName "DNS Zone Contributor" --resource-name <zone name> --resource-type Microsoft.Network/DNSZones --resource-group <resource group name>
}

########################################################################
# DESTROY
########################################################################

function delete_resource_groups() {
    echo_step "Deleting all resource groups..."
    az group delete --yes --name "clusters"
    az group delete --yes --name "common"
    az group delete --yes --name "monitoring"
}

function delete_service_principal() {
    local name # Input 1
    name="${1}"

    echo -e "Service principal: deleting credentials in keyvault..."
    az keyvault secret delete --vault-name "${RADIX_RESOURCE_KEYVAULT}" -n "${name}"
    echo -e "Service principal: deleting user in az ad..."
    az ad sp delete --id "http://${name}"
}

function delete_all_system_users() {
    ask_user "Delete all system users?" "This will delete users and credentials in keyvault."
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]
    then
        echo_step "Maybe we can terminate them later then. Exiting."
        return
    fi

    delete_service_principal "${RADIX_SYSTEM_USER_CLUSTER}"
    delete_service_principal "${RADIX_SYSTEM_USER_DNS}"
    delete_service_principal "${RADIX_SYSTEM_USER_CONTAINER_REGISTRY_READER}"
    delete_service_principal "${RADIX_SYSTEM_USER_CONTAINER_REGISTRY_CICD}"
}

function destroy() {
    echo_step "This is the imminent destruction of everything."
    ask_user "Do you want to continue?"
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]
    then
        echo_step "Destruction halted by user input ...For now. Exiting."
        exit 0
    fi

    echo_step "And so doom has come to radix infrastructure..."
    delete_all_system_users
    delete_resource_groups
}

########################################################################
# INTERFACE
########################################################################

# Misc az queries
# az group list --query '[].name'

function show_help() {
    echo -e "${__style_yellow}Provision prerequisite infrastructure for radix platform${__style_end}"
    echo -e ""
    echo -e "${__style_green}Configuration:${__style_end}"
    echo -e "- Environment : ${RADIX_INFRASTRUCTURE_ENVIRONMENT}"
    echo -e "- Region      : ${RADIX_INFRASTRUCTURE_REGION}"
    echo -e "- Subscription: ${RADIX_INFRASTRUCTURE_SUBSCRIPTION}"
    echo -e ""
    echo -e "Commands:"
    echo -e "- ${__style_green}install${__style_end}: Install all prerequiste infrastructure, system users, permissions etc step by step."
    echo -e "- ${__style_green}destroy${__style_end}: Destroy all prerequiste infrastructure, system users, permissions etc step by step."
    echo -e ""
    echo -e "Be aware that it is possible to create havoc with this script. You have been warned."
}

function install() {
    echo_step "Provision all prerequisite infrastructure."
    echo -e "Use radix-boot to provision clusters when all prerequisite infrastructure is ready."
    ask_user "Do you want to continue?"
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]
    then
        echo -e "Exiting install."
        exit 0
    fi
    
    ask_user "Should I provision the resource groups?" "This will reset all permissions on existing groups."    
    if [[ "$REPLY" =~ ^[Yy]$ ]]
    then
        provision_resource_groups
        set_permissions_on_all_resource_groups
    fi

    ask_user "Should I provision all the common resources?" "This will reset all permissions on existing resources."    
    if [[ "$REPLY" =~ ^[Yy]$ ]]
    then
        provision_common_resources
    fi

    ask_user "Should I provision all the system users?" "New users will be created and credentials will be stored in keyvault.\nExisting users and credentials will not be touched."    
    if [[ "$REPLY" =~ ^[Yy]$ ]]
    then
        create_service_principal "${RADIX_SYSTEM_USER_CLUSTER}" "A system user that own all clusters in ${RADIX_INFRASTRUCTURE_ENVIRONMENT} environment."
        create_service_principal "${RADIX_SYSTEM_USER_DNS}" "A system user for providing external-dns k8s component access to Azure DNS."
        create_service_principal "${RADIX_SYSTEM_USER_CONTAINER_REGISTRY_READER}" "A system user that should only be able to pull images from container registry."
        create_service_principal "${RADIX_SYSTEM_USER_CONTAINER_REGISTRY_CICD}" "A system user for providing radix cicd access to container registry."
    fi

    ask_user "Container registry: Should I set permissions for system users?"    
    if [[ "$REPLY" =~ ^[Yy]$ ]]
    then
        set_permissions_on_acr
    fi    

    ask_user "DNS: Should I set permissions for system users?"    
    if [[ "$REPLY" =~ ^[Yy]$ ]]
    then
        set_permissions_on_dns
    fi

    echo_step "Install done."
}

function parse_arguments() {    

    case "$1" in
        "-help" | "-h" )
            show_help
            ;;

        "install" )
            set_subscription
            install
            ;;

        "destroy" )
            set_subscription
            destroy
            ;;

        *)
            show_help
            ;;
    esac    
}

########################################################################
# MAIN
########################################################################

parse_arguments "$@"