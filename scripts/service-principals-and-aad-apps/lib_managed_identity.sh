#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Library for often used managed identity functions.

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

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap_managed_identities.sh

#######################################################################################
### START
###

#######################################################################################
### Check for prerequisites binaries
###

printf "Check for neccesary executables for \"$(basename ${BASH_SOURCE[0]})\"... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting... " >&2
    exit 1
}
printf "Done.\n"

#######################################################################################
### FUNCTIONS
###

function create_managed_identity() {
    local id_name # Input 1
    local testID

    id_name="$1"

    printf "Working on managed identity \"${id_name}\": "

    printf "Creating managed identity..."

    # Return if missing inputs.
    [ $# -ne 1 ] && {
        printf "missing inputs.\n"
        return
    }

    testID="$(az identity show --name "${id_name}" --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --subscription "${AZ_SUBSCRIPTION_ID}" --output tsv 2>/dev/null)"
    if [ -z "${testID}" ]; then
        createIdentity="$(az identity create --name ${id_name} --resource-group "${AZ_RESOURCE_GROUP_COMMON}" --subscription "${AZ_SUBSCRIPTION_ID}" --query clientId --output tsv --only-show-errors)"
        # It takes some time before the managed identity is registered in the Graph database. A role assignment cannot be created until it has.
        # Wait for managed identity to be registered in the Graph database:
        while [ -z "$(az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals?\$filter=appId eq '${createIdentity}'" --subscription "${AZ_SUBSCRIPTION_ID}" --query value[].id --output tsv)" ]; do
            printf "."
            sleep 3
        done
        printf "Done.\n"
    else
        printf "exists, skipping.\n"
    fi
}

function create_role_assignment_for_identity() {
    local id_name   # Input 1
    local role_name # Input 2
    local scope     # Input 3
    local id
    local testID
    local testRA

    id_name="$1"
    role_name="$2"
    scope="$3"

    printf "Working on managed identity \"${id_name}\": "

    printf "Creating role assignment..."

    # Return if missing inputs.
    [ $# -ne 3 ] && {
        printf "missing inputs.\n"
        return
    }

    testID="$(az rest \
        --method GET \
        --url "https://graph.microsoft.com/v1.0/servicePrincipals?\$filter=appId eq '$(az identity show --name ${id_name} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --subscription ${AZ_SUBSCRIPTION_ID} --query clientId --output tsv 2>/dev/null)'" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --query value[].id \
        --output tsv \
        2>/dev/null)"
    if [ "${testID}" ]; then
        assign_role "$id_name" "$role_name" "$scope" "$testID"
    else
        printf "missing identity.\n"
    fi
}

function assign_role() {
    local id_name=$1
    local role_name=$2
    local scope=$3
    local testID=$4

    local id="${testID}"

    if [[ -z $id ]]; then
        id=$(az ad app list --filter "displayName eq '$id_name'" --query [].appId --output tsv)
    fi

    testRA="$(az role assignment list \
        --assignee "${id}" \
        --subscription "${AZ_SUBSCRIPTION_ID}" \
        --all \
        --query "[?roleDefinitionName=='${role_name}' && scope=='${scope}']" \
        --output tsv 2>/dev/null)"

    printf "Assigning \"%s\" to \"%s\"... " "${role_name}" "${id_name}"
    if [ -z "${testRA}" ]; then
        az role assignment create \
            --role "${role_name}" \
            --assignee "${id}" \
            --scope "${scope}" \
            --subscription "${AZ_SUBSCRIPTION_ID}" \
            --output none \
            --only-show-errors
        printf "Done.\n"
    else
        printf "exists, skipping.\n"
    fi
}

function create_custom_role() {
    custom_role_json_file=$1
    role_name=$2
    role_definition=$(az role definition list --name "$role_name" --query [].assignableScopes[] --output tsv)
    if [[ -z ${role_definition} ]]; then
        printf "Creating role definition..."
        az role definition create --role-definition "@${custom_role_json_file}" 2>/dev/null
        while [ -z "$(az role definition list --query "[?roleName=='$role_name'].name" -otsv)" ]; do
            sleep 5
            printf "."
        done
        printf "...Done.\n"
    elif [[ ! ${role_definition[@]} =~ ${AZ_SUBSCRIPTION_ID} ]]; then
        echo "ERROR: Role definition exists, but subscription ${AZ_SUBSCRIPTION_ID} is not an assignable scope. This script does not update it, so it must be done manually." >&2
        return
    else
        echo "$role_name role definition exists."
    fi
}

function add-federated-gh-credentials {
    local mi_name
    local repo
    local branch
    local environment

    mi_name="$1"
    repo="$2"
    branch="$3"
    environment="$4"

    if [[ -z $environment ]]; then
        subject="repo:equinor/${repo}:ref:refs/heads/${branch}"
    else
        subject="repo:equinor/${repo}:environment:${environment}"
    fi

    printf "Adding federated GH credentials to MI ${mi_name}... "
    az identity federated-credential create \
        --identity-name "${mi_name}" \
        --name "${repo}-gh-actions-${branch}-${RADIX_ENVIRONMENT}" \
        --resource-group "${AZ_RESOURCE_GROUP_COMMON}" \
        --audiences "api://AzureADTokenExchange" \
        --issuer "https://token.actions.githubusercontent.com" \
        --subject "${subject}" \
        --only-show-errors >/dev/null || {
        echo -e "ERROR: Could not add federated GH credentials to managed identity ${mi_name}." >&2
        exit 1
    }
    printf "Done!\n"
}

function create-role-and-rolebinding {
    local role_path
    local rolebinding_path

    role_path="$1"
    rolebinding_path="$2"

    printf "Creating role...\n"
    kubectl apply -f "${role_path}" || {
        echo -e "ERROR: Could not create role." >&2
        exit 1
    }
    printf "Done\n"

    printf "Creating rolebinding...\n"
    kubectl apply -f "${rolebinding_path}" || {
        echo -e "ERROR: Could not create rolebinding." >&2
        exit 1
    }
    printf "Done\n"
}

# function set-kv-policy {
#     local object_id
#     local permissions

#     object_id=$1
#     permissions=$2

#     printf "Creating vault access policy on %s for %s...\n" "${AZ_RESOURCE_KEYVAULT}" "${object_id}"
#     az keyvault set-policy \
#         --name "${AZ_RESOURCE_KEYVAULT}" \
#         --secret-permissions ${permissions} \
#         --object-id "${object_id}" \
#         --only-show-errors >/dev/null || {
#         echo -e "ERROR: Could not create vault access policy on ${AZ_RESOURCE_KEYVAULT}." >&2
#         exit 1
#     }
#     printf "Done\n"
# }

function create-az-role {
    local name
    local description
    local actions
    local scopes

    name=$1
    description=$2
    actions=$3
    scopes=$4

    local temp_file="/tmp/$(uuidgen)"
    cat <<EOF >>${temp_file}
    {
        "Name": "$name",
        "Id": "",
        "IsCustom": true,
        "Description": "$description",
        "Actions": $actions,
        "AssignableScopes": $scopes
    }
EOF
    create_custom_role "${temp_file}" "${name}"
    rm ${temp_file}
    printf "Done\n"
}

#######################################################################################
### END
###
