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
hash envsubst 2>/dev/null || {
    echo -e "\nERROR: envsubst not found in PATH. Exiting..." >&2
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

WORKDIR_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

mi_name=radix-cicd-canary-scaler-dr
mi-exists ${mi_name} || { 
        create_managed_identity ${mi_name}
        client_id=$(az identity show --name ${mi_name} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --subscription ${AZ_SUBSCRIPTION_ID} --query clientId -o tsv)
        printf "${yel}""WARNING: New managed identity's client ID, ${client_id}, must be added to GitHub Actions workflow config file, ${AZ_SUBSCRIPTION_NAME}-${AZ_LOCATION}.cfg${normal}\n" >&2 
    }

permission=("Microsoft.ContainerService/managedClusters/listClusterUserCredential/action" "Microsoft.ContainerService/managedClusters/read" "Microsoft.ContainerService/managedClusters/runCommand/action" "Microsoft.ContainerService/managedclusters/commandResults/read")
permission_json=$(jq -c -n '$ARGS.positional' --args "${permission[@]}")
# scopes=("/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b" "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a")
scopes=("/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b" "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a" "/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04")
scopes_json=$(jq -c -n '$ARGS.positional' --args "${scopes[@]}")

create-az-role "${AKS_COMMAND_RUNNER_ROLE_NAME}" "Can execute 'az aks command invoke' on AKS cluster." "$permission_json" "$scopes_json"
tmp_file_name="/tmp/$(uuidgen)"
get-mi-object-id ${tmp_file_name} ${mi_name}
mi_object_id=$(cat ${tmp_file_name})
rm ${tmp_file_name}
# TODO: DevOps issue 259748, downgrade Contributor role when new role is ready
# https://github.com/equinor/Solum/issues/10900
create_role_assignment_for_identity "${mi_name}" "${AKS_COMMAND_RUNNER_ROLE_NAME}" "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_CLUSTERS}"
set-kv-policy "${mi_object_id}" "get"
create-role-and-rolebinding "${WORKDIR_PATH}/role.yaml" "${WORKDIR_PATH}/rolebinding.yaml"
modify-role-binding ${mi_object_id}
add-federated-gh-credentials ${mi_name} "radix-platform" "master"
