#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Library for often used service principal functions.
# -

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

function update_service_principal_credentials_in_az_keyvault() {
    local name            # Input 1, string
    local id              # Input 2, string
    local password        # Input 3, string
    local description     # Input 4, string, optional
    local secret_id       # Input 5, string, optional
    local expiration_date # Input 6, string, optional
    local secretkey       # Input 7, string
    local tmp_file_path
    local template_path
    local script_dir_path
    local expires=()

    name="$1"
    id="$2"
    password="$3"
    description="${4:-}"
    secret_id="${5:-}"
    expiration_date="${6:-}"
    secretkey="$7"

    tenantId="$(az ad sp show --id "${id}" --query appOwnerOrganizationId --output tsv)"
    script_dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    template_path="${script_dir_path}/template-credentials.json"

    if [ ! -e "$template_path" ]; then
        echo "Error in func \"update_service_principal_credentials_in_az_keyvault\": sp credentials template not found at ${template_path}" >&2
        exit 1
    fi

    # Use jq together with a credentials json template to ensure we end up with valid json, and then put the result into a tmp file which we will upload to the keyvault.
    tmp_file_path="${script_dir_path}/${name}.json"
    cat "$template_path" | jq -r \
        --arg name "${name}" \
        --arg id "${id}" \
        --arg password "${password}" \
        --arg description "${description}" \
        --arg tenantId "${tenantId}" \
        --arg secretId "${secret_id}" \
        '.name=$name | .id=$id | .password=$password | .description=$description | .tenantId=$tenantId | .secretId=$secretId' >"$tmp_file_path"

    # show result
    # cat "${tmp_file_path}"

    if [[ -n ${expiration_date} ]]; then
        expires=(--expires "${expiration_date}")
    fi

    # Upload to keyvault
    if ! az keyvault secret set --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${secretkey}" --file "${tmp_file_path}" ${expires[@]+"${expires[@]}"} 2>&1 >/dev/null; then
        rm -f "$tmp_file_path"
        return 1
    fi

    rm -f "$tmp_file_path"
}

function refresh_ad_app_and_store_credentials_in_ad_and_keyvault() {
    local name        # Input 1
    local secretkey   # Input 2
    local description # Input 3, optional
    local password
    local id

    name="$1"
    secretkey="$2"
    description="${3:-}"

    printf "Working on \"${name}\": Appending new credentials in Azure AD..."

    id="$(az ad app list --filter "displayname eq '${name}'" --query '[].appId' --output tsv)"
    password="$(az ad app credential reset --id "${id}" --display-name "rbac" --append --query password --output tsv)"
    sleep 5
    secret="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='rbac'], &endDateTime)[-1:].{endDateTime:endDateTime,keyId:keyId}")"
    secret_id="$(echo "${secret}" | jq -r .[].keyId)"
    expiration_date="$(echo "${secret}" | jq -r .[].endDateTime | sed 's/\..*//')"

    printf "Update credentials in keyvault..."
    update_service_principal_credentials_in_az_keyvault "${name}" "${id}" "${password}" "${description}" "${secret_id}" "${expiration_date}" "${secretkey}"

    printf "Done.\n"
}

function exit_if_user_does_not_have_required_ad_role() {
    # Based on https://docs.microsoft.com/en-us/graph/api/rbacapplication-list-roleassignments?view=graph-rest-1.0
    # There is no azcli way of doing this, just powershell or rest api, so we will have to query the graph api.
    local currentUserRoleAssignment

    printf "Checking if you have required AZ AD role active..."
    currentUserRoleAssignment="$(az rest \
        --method GET \
        --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?\$filter=roleDefinitionId eq 'cf1c38e5-3621-4004-a7cb-879624dced7c'&\$expand=principal" |
        jq '.value[] | select(.principalId=="'$(az ad signed-in-user show --query id -otsv)'")')"

    if [[ -z "$currentUserRoleAssignment" ]]; then
        echo "You must activate AZ AD role \"Application Developer\" in PIM before using this script. Exiting..." >&2
        exit 1
    fi

    printf "Done.\n"
}
