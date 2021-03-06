#!/bin/bash


#######################################################################################
### PURPOSE
### 

# Library for often used service principal functions.
# - 


#######################################################################################
### Check for prerequisites binaries
###

printf "Check for neccesary executables for \"$(basename ${BASH_SOURCE[0]})\"... "
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
hash jq 2> /dev/null  || { echo -e "\nError: jq not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"


#######################################################################################
### FUNCTIONS
### 


function update_service_principal_credentials_in_az_keyvault() {
    local name              # Input 1, string
    local id                # Input 2, string
    local password          # Input 3, string
    local description       # Input 4, string, optional
    local tmp_file_path
    local template_path
    local script_dir_path

    name="$1"
    id="$2"
    password="$3"
    description="$4"    
    tenantId="$(az ad sp show --id ${id} --query appOwnerTenantId --output tsv)"
    script_dir_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    template_path="${script_dir_path}/template-credentials.json"

    if [ ! -e "$template_path" ]; then
        echo "Error in func \"update_service_principal_credentials_in_az_keyvault\": sp credentials template not found at ${template_path}"
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
    '.name=$name | .id=$id | .password=$password | .description=$description | .tenantId=$tenantId' > "$tmp_file_path"
    
    # show result
    # cat "${tmp_file_path}"

    # Upload to keyvault
    az keyvault secret set --vault-name "${AZ_RESOURCE_KEYVAULT}" -n "${name}" -f "${tmp_file_path}" 2>&1 >/dev/null

    # Clean up
    rm -rf "$tmp_file_path"    
}
 
function create_service_principal_and_store_credentials() {

    local name          # Input 1
    local description   # Input 2, optional
    local password
    local id

    name="$1"
    description="$2"

    printf "Working on \"${name}\": Creating service principal..."

    # Exit gracefully if the sp exist
    local testSP
    testSP="$(az ad sp show --id http://${name} --query appDisplayName --output tsv 2> /dev/null)"
    if [ ! -z "$testSP" ]; then
        printf "${name} exist, skipping.\n"
        return
    fi

    password="$(az ad sp create-for-rbac --skip-assignment --name http://${name} --query password --output tsv)"
    id="$(az ad sp show --id http://${name} --query appId --output tsv)"

    printf "Update credentials in keyvault..."
    update_service_principal_credentials_in_az_keyvault "${name}" "${id}" "${password}" "${description}"

    printf "Done.\n"
}
 
function refresh_service_principal_and_store_credentials_in_ad_and_keyvault() {

    local name          # Input 1
    local description   # Input 2, optional
    local password
    local id

    name="$1"
    description="$2"

    printf "Working on \"${name}\": Appending new credentials in Azure AD..."

    # The --credential-description option is very prone to fail, unfortunately
    password="$(az ad sp credential reset --name http://${name} --append --query password --output tsv)"
    id="$(az ad sp show --id http://${name} --query appId --output tsv)"

    printf "Update credentials in keyvault..."
    update_service_principal_credentials_in_az_keyvault "${name}" "${id}" "${password}" "${description}"

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

    # The --credential-description option is very prone to fail, unfortunately
    id="$(az ad app list --identifier-uri http://${name} --query '[].appId' -o tsv)" 
    password="$(az ad app credential reset --id ${id} --append --query password --output tsv)"

    printf "Update credentials in keyvault..."
    update_service_principal_credentials_in_az_keyvault "${name}" "${id}" "${password}" "${description}"

    printf "Done.\n"
}

function delete_service_principal_and_stored_credentials() {
    local name # Input 1
    name="${1}"
    
    printf "Working on service principal \"${name}\": "
    
    printf "deleting user in az ad..."
    local az_sp_fullname="$name"
    [ "$az_sp_fullname" != "http://"* ] && { az_sp_fullname="http://${name}"; }
    az ad sp delete --id "${az_sp_fullname}" --output none
    
    printf "deleting credentials in keyvault..."
    az keyvault secret delete --vault-name "${AZ_RESOURCE_KEYVAULT}" -n "${name}" --output none
    printf "Done.\n"
}

function delete_ad_app_and_stored_credentials() {
    local name # Input 1
    name="${1}"

    printf "Working on ad app \"${name}\": "

    # Get id from key vault as trying to use the name is just hopeless for client apps when using cli
    app_id="$(az keyvault secret show --vault-name ${AZ_RESOURCE_KEYVAULT} --name ${name} | jq -r .value | jq -r .id)"
    
    printf "deleting app in az ad..."
    az ad app delete --id "${app_id}" --output none
    
    printf "deleting credentials in keyvault..."
    az keyvault secret delete --vault-name "${AZ_RESOURCE_KEYVAULT}" -n "${name}" --output none
    printf "Done.\n"
}

function exit_if_user_does_not_have_required_ad_role(){
    # Based on https://docs.microsoft.com/en-us/azure/active-directory/users-groups-roles/roles-view-assignments#view-role-assignments-using-microsoft-graph-api
    # There is no azcli way of doing this, just powershell or rest api, so we will have to query the graph api.
    # The Azure PIM portal use a rest api dedicated to PIM and so can run a more fine grained request, but this is not recommended for third party use.
    local currentUserRoleAssignment

    printf "Checking if you have required AZ AD role active..."
    currentUserRoleAssignment="$(curl -s -X GET --header "Authorization: Bearer $(az account get-access-token --resource https://graph.windows.net/ | jq -r .accessToken)" -H 'Content-Type: application/json' -H 'Cache-Control: no-cache' 'https://graph.windows.net/myorganization/roleAssignments?$filter=roleDefinitionId%20eq%20%27cf1c38e5-3621-4004-a7cb-879624dced7c%27%20and%20resourceScopes/any(x:x%20eq%20%27/%27)&$expand=principal&api-version=1.61-internal' \
        | jq -r --arg principalId "$(az ad signed-in-user show --query objectId -otsv)" '.value[] | select(.roleDefinitionId=="cf1c38e5-3621-4004-a7cb-879624dced7c" and .principalId==$principalId)'//empty)"

    if [[ -z "$currentUserRoleAssignment" ]]; then
        echo "You must activate AZ AD role \"Application Developer\" in PIM before using this script. Exiting..."
        exit 0
    fi

    printf "Done.\n"
}
