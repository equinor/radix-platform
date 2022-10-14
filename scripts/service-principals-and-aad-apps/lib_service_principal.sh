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
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
hash jq 2> /dev/null  || { echo -e "\nERROR: jq not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"


#######################################################################################
### FUNCTIONS
###


function update_service_principal_credentials_in_az_keyvault() {
    local name              # Input 1, string
    local id                # Input 2, string
    local password          # Input 3, string
    local description       # Input 4, string, optional
    local secret_id         # Input 5, string, optional
    local expiration_date   # Input 6, string, optional
    local tmp_file_path
    local template_path
    local script_dir_path

    name="$1"
    id="$2"
    password="$3"
    description="$4"
    secret_id="$5"
    expiration_date="$6"
    tenantId="$(az ad sp show --id ${id} --query appOwnerTenantId --output tsv)"
    script_dir_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
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
    '.name=$name | .id=$id | .password=$password | .description=$description | .tenantId=$tenantId | .secretId=$secretId' > "$tmp_file_path"

    # show result
    # cat "${tmp_file_path}"

    if [[ -n ${expiration_date} ]]; then
        expires="--expires "${expiration_date}""
    fi

    # Upload to keyvault
    az keyvault secret set --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${name}" --file "${tmp_file_path}" ${expires} 2>&1 >/dev/null

    # Clean up
    rm -rf "$tmp_file_path"
}


function update_app_credentials_in_az_keyvault() {
    local name              # Input 1, string
    local id                # Input 2, string
    local password          # Input 3, string
    local description       # Input 4, string, optional
    local secret_id         # Input 5, string, optional
    local expiration_date   # Input 6, string, optional
    local keyvault          # Input 7, string 
    local tmp_file_path
    local template_path
    local script_dir_path

    name="$1"
    id="$2"
    password="$3"
    description="$4"
    secret_id="$5"
    expiration_date="$6"
    keyvault="$7"
    # tenantId="$(az ad app show --id ${id} --query appOwnerTenantId --output tsv)"
    script_dir_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
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
    --arg tenantId "" \
    --arg secretId "${secret_id}" \
    '.name=$name | .id=$id | .password=$password | .description=$description | .tenantId=$tenantId | .secretId=$secretId' > "$tmp_file_path"

    # show result
    # cat "${tmp_file_path}"

    if [[ -n ${expiration_date} ]]; then
        expires="--expires ${expiration_date}"
        echo "${expires}"
    fi

    # Upload to keyvault
    az keyvault secret set --vault-name "${keyvault}" --name "${name}" --file "${tmp_file_path}" ${expires} 2>&1 >/dev/null

    # Clean up
    rm -rf "$tmp_file_path"
}

function update_ad_app_owners() {
    local name              # Input 1
    local ad_group          # Input 2, optional
    local ad_group_users
    local app_owners
    local user_object_id
    local user_email
    local id

    name="$1"
    ad_group="$2"

    if [[ -z ${ad_group} ]]; then
        ad_group="Radix"
    fi

    id="$(az ad app list --display-name "${name}" --query [].appId --output tsv --only-show-errors)"
    printf "Updating owners of app registration \"${name}\"..."

    ad_group_users=$(az ad group member list --group "${ad_group}" --query "[].[id,userPrincipalName]" --output tsv --only-show-errors)

    app_owners=$(az ad app owner list --id "${id}" --query "[?[].accountEnabled==true].[id,userPrincipalName]" --output tsv --only-show-errors)

    while IFS=$'\t' read -r -a line; do
        user_object_id=${line[0]}
        user_email=${line[1]}
        if [[ ! ${app_owners[@]} =~ ${user_object_id} ]]; then
            printf "Adding ${user_email} to ${name}..."
            az ad app owner add --id "${id}" --owner-object-id "${user_object_id}" --output none --only-show-errors
            printf " Done.\n"
        fi
    done <<< "${ad_group_users}"
    unset IFS

    while IFS=$'\t' read -r -a line; do
        user_object_id=${line[0]}
        user_email=${line[1]}
        if [[ ! ${ad_group_users[@]} =~ ${user_object_id} ]]; then
            printf "Removing ${user_email} from ${name}"
            az ad app owner remove --id "${id}" --owner-object-id "${user_object_id}" --output none --only-show-errors
            printf " Done.\n"
        fi
    done <<< "${app_owners}"
    unset IFS
    printf " Done.\n"
}

function update_service_principal_owners() {
    # As the Azure CLI does not support adding or removing owners to a service principal (enterprise application), it is possible to send a request to Microsoft Graph rest API.
    # https://docs.microsoft.com/en-us/graph/api/serviceprincipal-post-owners?view=graph-rest-1.0
    local name              # Input 1
    local ad_group          # Input 2, optional
    local ad_group_users
    local sp_owners
    local user_object_id
    local user_email
    local id

    name="$1"
    ad_group="$2"

    if [[ -z ${ad_group} ]]; then
        ad_group="Radix"
    fi

    sp_obj_id="$(az ad sp list --display-name "${name}" --query [].id --output tsv --only-show-errors)"

    printf "Updating owners of service principal \"${name}\"..."

    ad_group_users=$(az ad group member list --group "${ad_group}" --query "[].[id,userPrincipalName]" --output tsv --only-show-errors)

    sp_owners=$(az ad sp owner list --id ${sp_obj_id} --query "[?[].accountEnabled==true].[id,userPrincipalName]" --output tsv --only-show-errors)

    while IFS=$'\t' read -r -a line; do
        user_object_id=${line[0]}
        user_email=${line[1]}
        if [[ ! ${sp_owners[@]} =~ ${user_object_id} ]]; then
            printf "Adding ${user_email} to ${name}..."
            az rest --method POST --url https://graph.microsoft.com/v1.0/servicePrincipals/$sp_obj_id/owners/\$ref \
                --headers Content-Type=application/json --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/users/$user_object_id\"}"
            printf " Done.\n"
        fi
    done <<< "${ad_group_users}"
    unset IFS

    while IFS=$'\t' read -r -a line; do
        user_object_id=${line[0]}
        user_email=${line[1]}
        if [[ ! ${ad_group_users[@]} =~ ${user_object_id} ]]; then
            echo "Removing ${user_email} from ${name}..."
            az rest --method DELETE --url https://graph.microsoft.com/v1.0/servicePrincipals/$sp_obj_id/owners/\$ref \
                --headers Content-Type=application/json --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/users/$user_object_id\"}"
            printf " Done.\n"
        fi
    done <<< "${sp_owners}"
    unset IFS

    printf " Done.\n"
}

function create_service_principal_and_store_credentials() {

    local name          # Input 1
    local description   # Input 2, optional
    local password
    local id

    name="$1"
    description="$2"

    printf "Working on \"${name}\": Creating service principal..."

    # Skip creation if the sp exist
    local testSP
    testSP="$(az ad sp list --display-name "${name}" --query [].appId --output tsv 2> /dev/null)"
    if [ -z "$testSP" ]; then
        printf "creating ${name}..."
        password="$(az ad sp create-for-rbac --name "${name}" --query password --output tsv)"
        id="$(az ad sp list --display-name "${name}" --query [].appId --output tsv)"
        secret="$(az ad sp credential list --id "${id}" --query "sort_by([?displayName=='rbac'], &endDateTime)[-1:].{endDateTime:endDateTime,keyId:keyId}")"
        secret_id="$(echo "${secret}" | jq -r .[].keyId)"
        expiration_date="$(echo "${secret}" | jq -r .[].endDateTime | sed 's/\..*//')"
        az ad sp update --id "${id}" --set notes="${description}"
        printf " Done.\n"

        printf "Update credentials in keyvault..."
        update_service_principal_credentials_in_az_keyvault "${name}" "${id}" "${password}" "${description}" "${secret_id}" "${expiration_date}"
    else
        printf "${name} exists.\n"
    fi

    printf "Update owners of app registration..."
    update_ad_app_owners "${name}"

    printf "Update owners of service principal..."
    update_service_principal_owners "${name}"

    printf "Done.\n"
}

function create_oidc_and_federated_credentials() {
    echo ""
    APP_NAME="$1"
    export SUBSCRIPTION_ID="$2"
    export REPO="$3"
    export ENVIRONMENT="$4"
    printf "Working on \"${APP_NAME}\"\n"
    wait_for_pim_app_developer_role
    wait_for_ad_owner_role
    app_id=$(az ad app list --filter "displayName eq '$APP_NAME'" --query [].appId --output tsv)
    if [ -z "$app_id" ]; then
        printf "creating ${APP_NAME}...\n"
        app_id=$(az ad app create --display-name "$APP_NAME" --query appId --output tsv)
    fi

    #printf "Update owners of app registration..."
    update_ad_app_owners "${APP_NAME}"

    #printf "Update owners of service principal..."
    update_service_principal_owners "${APP_NAME}"
    script_dir_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    config=$(envsubst < "${script_dir_path}/oidc.json")
    printf "Checking if federated identity credential already exists..."
    fic=$(echo "$config" | jq '.federatedCredential')

    fic_name=$(echo "$fic" | jq -r '.name')
    fic_id=$(az ad app federated-credential list --id "$app_id" --query "[?name == '$fic_name'].id" --output tsv)

    if [[ -z "$fic_id" ]]; then
        printf "Creating federated identity credential..."
        az ad app federated-credential create --id "$app_id" --parameters "$fic" --output none
        printf " Done.\n"
    else
        printf " Done.\n"
        printf "Updating existing federated identity credential..."
        az ad app federated-credential update --id "$app_id" --federated-credential-id "$fic_id" --parameters "$fic" --output none
        printf " Done.\n"
    fi
    printf "Checking if service principal already exists..."
    sp_id=$(az ad sp list --filter "appId eq '$app_id'" --query [].id --output tsv)
    if [[ -z "$sp_id" ]]; then
        #printf "Creating service principal..."
        sp_id=$(az ad sp create --id "$app_id" --query id --output tsv)
        printf " Done.\n"
    else
        printf " Done.\n"
    fi

    printf "Creating role assignments..."
    ras=$(echo "$config" | jq -c '.roleAssignments[]')
    echo "$ras" | while read -r ra; do
        role=$(echo "$ra" | jq -r '.role')
        scope=$(echo "$ra" | jq -r '.scope')
        #echo "Assigning role '$role' at scope '$scope'..."
        az role assignment create --role Contributor --subscription ${SUBSCRIPTION_ID} --assignee-object-id ${sp_id} --assignee-principal-type ServicePrincipal --scope "${scope}" --output none 2>&1 > /dev/null
        printf " Done.\n"
    done

    if ! gh auth status >/dev/null 2>&1; then
        echo "You need to login: "
        gh auth login
    fi

    gh api --method PUT "repos/equinor/${REPO}/environments/${ENVIRONMENT}" 2>&1 >/dev/null
    echo 'Updating GitHub secrets...'
    gh secret set 'AZURE_CLIENT_ID' --body "$app_id" --repo "equinor/${REPO}" --env "$ENVIRONMENT"
    gh secret set 'AZURE_SUBSCRIPTION_ID' --body "$SUBSCRIPTION_ID" --repo "equinor/${REPO}" --env "$ENVIRONMENT"
    gh secret set 'AZURE_TENANT_ID' --body $(az ad signed-in-user show --query id -otsv) --repo "equinor/${REPO}" --env "$ENVIRONMENT"
}

function refresh_service_principal_and_store_credentials_in_ad_and_keyvault() {

    local name          # Input 1
    local description   # Input 2, optional
    local password
    local id

    name="$1"
    description="$2"

    printf "Working on \"${name}\": Appending new credentials in Azure AD..."

    id="$(az ad sp list --display-name "${name}" --query [].appId --output tsv)"
    password="$(az ad sp credential reset --name "${id}" --display-name "rbac" --append --query password --output tsv)"
    secret="$(az ad sp credential list --id "${id}" --query "sort_by([?displayName=='rbac'], &endDateTime)[-1:].{endDateTime:endDateTime,keyId:keyId}")"
    secret_id="$(echo "${secret}" | jq -r .[].keyId)"
    expiration_date="$(echo "${secret}" | jq -r .[].endDateTime | sed 's/\..*//')"

    printf "Update credentials in keyvault..."
    update_service_principal_credentials_in_az_keyvault "${name}" "${id}" "${password}" "${description}" "${secret_id}" "${expiration_date}"

    printf "Done.\n"
}

function refresh_ad_app_and_store_credentials_in_ad_and_keyvault() {

    local name          # Input 1
    local description   # Input 2, optional
    local password
    local id

    name="$1"
    description="$2"

    printf "Working on \"${name}\": Appending new credentials in Azure AD..."

    id="$(az ad app list --display-name "${name}" --query '[].appId' --output tsv)"
    password="$(az ad app credential reset --id "${id}" --display-name "rbac" --append --query password --output tsv)"
    secret="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='rbac'], &endDateTime)[-1:].{endDateTime:endDateTime,keyId:keyId}")"
    secret_id="$(echo "${secret}" | jq -r .[].keyId)"
    expiration_date="$(echo "${secret}" | jq -r .[].endDateTime | sed 's/\..*//')"

    printf "Update credentials in keyvault..."
    update_service_principal_credentials_in_az_keyvault "${name}" "${id}" "${password}" "${description}" "${secret_id}" "${expiration_date}"

    printf "Done.\n"
}

function delete_service_principal_and_stored_credentials() {
    local name # Input 1
    name="${1}"

    printf "Working on service principal \"${name}\": "

    printf "deleting user in az ad..."
    id="$(az ad sp list --display-name "${name}" --query [].appId --output tsv)"
    az ad sp delete --id "${id}" --output none

    printf "deleting credentials in keyvault..."
    az keyvault secret delete --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${name}" --output none
    printf "Done.\n"
}

function delete_ad_app_and_stored_credentials() {
    local name # Input 1
    name="${1}"

    printf "Working on ad app \"${name}\": "

    # Get id from key vault as trying to use the name is just hopeless for client apps when using cli
    app_id="$(az keyvault secret show --vault-name ${AZ_RESOURCE_KEYVAULT} --name "${name}" | jq -r .value | jq -r .id)"

    printf "deleting app in az ad..."
    az ad app delete --id "${app_id}" --output none

    printf "deleting credentials in keyvault..."
    az keyvault secret delete --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${name}" --output none
    printf "Done.\n"
}

function exit_if_user_does_not_have_required_ad_role(){
    # Based on https://docs.microsoft.com/en-us/graph/api/rbacapplication-list-roleassignments?view=graph-rest-1.0
    # There is no azcli way of doing this, just powershell or rest api, so we will have to query the graph api.
    local currentUserRoleAssignment

    printf "Checking if you have required AZ AD role active..."
    currentUserRoleAssignment="$(az rest \
        --method GET \
        --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?\$filter=roleDefinitionId eq 'cf1c38e5-3621-4004-a7cb-879624dced7c'&\$expand=principal" \
        | jq '.value[] | select(.principalId=="'$(az ad signed-in-user show --query id -otsv)'")')"

    if [[ -z "$currentUserRoleAssignment" ]]; then
        echo "You must activate AZ AD role \"Application Developer\" in PIM before using this script. Exiting..." >&2
        exit 1
    fi

    printf "Done.\n"
}

function wait_for_pim_app_developer_role() {
    local currentUserRoleAssignment
    printf "Checking if you have required AZ AD role active..."
    currentUserRoleAssignment="$(az rest \
        --method GET \
        --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?\$filter=roleDefinitionId eq 'cf1c38e5-3621-4004-a7cb-879624dced7c'&\$expand=principal" \
        | jq '.value[] | select(.principalId=="'$(az ad signed-in-user show --query id -otsv)'")')"
    
    if [[ -z "$currentUserRoleAssignment" ]]; then
        printf "\n\"Application Developer\" in PIM not actived. Please do and wait for the progress dots\n"
        printf "Waiting."
        while [[ -z "$currentUserRoleAssignment" ]]; do
            currentUserRoleAssignment="$(az rest \
                --method GET \
                --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?\$filter=roleDefinitionId eq 'cf1c38e5-3621-4004-a7cb-879624dced7c'&\$expand=principal" \
                | jq '.value[] | select(.principalId=="'$(az ad signed-in-user show --query id -otsv)'")')"
            printf "."
            sleep 5
        done
        printf " Done.\n"
    else
        printf " Done.\n"
    fi
}

function wait_for_ad_owner_role() {
    local currentownerrole
    printf "Checking if you have required AZ AD ownership..."
    currentownerrole="$(az role assignment list --query "[?roleDefinitionName == 'Owner' && principalName == '$(az account show --query user.name -o tsv)']" | jq .[])"
    if [[ -z "$currentownerrole" ]]; then
        printf "\n\"Owner\" in Azure resources are not actived. Please do and wait for the progress dots\n"
        printf "Waiting."
        while [[ -z "$currentownerrole" ]]; do
            currentownerrole="$(az role assignment list --query "[?roleDefinitionName == 'Owner' && principalName == '$(az account show --query user.name -o tsv)']" | jq .[])"
            printf "."
            sleep 5
        done
    else
        printf " Done.\n"
    fi
}
