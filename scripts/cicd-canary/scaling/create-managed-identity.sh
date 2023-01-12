#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Create managed identity and modify rolebinding for MI to scale deplpoyment of radix-cicd-canary in a radix cluster

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./create-managed-identity.sh

# Script is idempotent. Knock yourself out.

#######################################################################################
### START
###

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

echo ""
echo "Create managed identity and configure RBAC for scheduled start and stop of radix-cicd-canary... "

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2
    exit 1
}
hash uuidgen 2>/dev/null || {
    echo -e "\nERROR: uuidgen not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}
printf "All is good."
echo ""

#######################################################################################
### Read inputs and configs
###

# Required inputs

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

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

script_dir_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/service-principals-and-aad-apps/lib_managed_identity.sh

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 0        
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
verify_cluster_access

function mi-exists {
    local mi_name=$1
    az identity show --name ${mi_name} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --subscription ${AZ_SUBSCRIPTION_ID} >/dev/null 2>&1 || (printf "MI ${mi_name} does not exist, creating...\n" && return 1)
}

function get-mi-object-id {
    local tmp_file=$1
    local mi_name=$2
    printf "Retrieving object-id of ${mi_name}...\n"
    local object_id=$(az identity show --name ${mi_name} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --subscription ${AZ_SUBSCRIPTION_ID} --query principalId -o tsv)  || {
        echo -e "ERROR: Could not retrieve object ID of MI ${mi_name}." >&2
        exit 1
    }
    echo $object_id > $tmp_file
    printf "Done\n"
}

function create-role-assignment {
    # TODO: DevOps issue 259748, downgrade Contributor role when new role is ready
    local object_id=$1
    printf "Assigning role to ${object_id} on scope of ${AZ_RESOURCE_GROUP_CLUSTERS}...\n"
    az role assignment create \
        --assignee-object-id $object_id \
        --assignee-principal-type ServicePrincipal \
        --role Contributor \
        --scope /subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_CLUSTERS} || {
            echo -e "ERROR: Could not assign role to ${object_id}." >&2
            exit 1
        }
    printf "Done\n"
}

function modify-role-binding {
    local object_id=$1
    printf "Modifying rolebinding to grant scaler role to MI ${object_id}...\n"
    kubectl patch rolebindings.rbac.authorization.k8s.io deployment-scaler \
        --namespace radix-cicd-canary \
        --type strategic \
        --patch '{"subjects":[{"apiGroup":"rbac.authorization.k8s.io","kind":"User","name":"'${object_id}'"}]}' || {        
            echo -e "ERROR: Could not modify deployment-scaler rolebinding." >&2
            exit 1
        }
}

function add-federated-gh-credentials {
    local mi_name=$1
    local branch=$2
    printf "Adding federated GH credentials to MI ${mi_name}...\n"
    az identity federated-credential create \
        --identity-name ${mi_name} \
        --name radix-platform-gh-actions-${branch} \
        --resource-group ${AZ_RESOURCE_GROUP_COMMON} \
        --audiences "api://AzureADTokenExchange" \
        --issuer https://token.actions.githubusercontent.com \
        --subject repo:equinor/radix-platform:ref:refs/heads/${branch} || {        
            echo -e "ERROR: Could not add federated GH credentials to managed identity ${mi_name}." >&2
            exit 1
        }
}

function create-role-and-rolebinding {
    printf "Creating role in radix-cicd-canary namespace...\n"
    kubectl apply -f $script_dir_path/role.yaml || {        
            echo -e "ERROR: Could not create role." >&2
            exit 1
        }
    printf "Done\n"
    printf "Creating rolebinding in radix-cicd-canary namespace...\n"
    kubectl apply -f $script_dir_path/rolebinding.yaml || {        
            echo -e "ERROR: Could not create rolebinding." >&2
            exit 1
        }
    printf "Done\n"
}

mi_name=radix-cicd-canary-scaler
mi-exists ${mi_name} || { 
        create_managed_identity ${mi_name}
        client_id=$(az identity show --name ${mi_name} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --subscription ${AZ_SUBSCRIPTION_ID} --query clientId -o tsv)
        printf "${yel}""WARNING: New managed identity's client ID, ${client_id}, must be added to GitHub Actions workflow config file, ${AZ_SUBSCRIPTION_NAME}-${AZ_LOCATION}.cfg${normal}\n" >&2 
    }
tmp_file_name="/tmp/$(uuidgen)"
get-mi-object-id ${tmp_file_name} ${mi_name}
mi_object_id=$(cat ${tmp_file_name})
rm ${tmp_file_name}
create-role-assignment ${mi_object_id}
create-role-and-rolebinding
modify-role-binding ${mi_object_id}
add-federated-gh-credentials ${mi_name} "master"