#!/usr/bin/env bash

# sh ./create-sp.sh 'env'

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"

# tenantId="$(az ad app show --id ${id} --query appOwnerOrganizationId --output tsv)"
script_dir_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template_path="${script_dir_path}/template-credentials.json"

if [ ! -e "$template_path" ]; then
    echo "Error in func \"update_service_principal_credentials_in_az_keyvault\": sp credentials template not found at ${template_path}" >&2
    exit 1
fi

if [[ $1 == "ext-mon" ]]; then
    APP_REGISTRATION="radix-ar-grafana-ext-mon"
    KEYVAULT="radix-keyv-extmon"
else
    APP_REGISTRATION="radix-ar-grafana-$1"
    KEYVAULT="radix-keyv-$1"
fi


cat << EOF
Will use the following configuration:

    -------------------------------------------------------------------
    -  APP REGISTRATION     : $APP_REGISTRATION
    -  KEYVAULT             : $KEYVAULT
    -------------------------------------------------------------------
    -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)
    -  AZ_USER                          : $(az account show --query user.name -o tsv)
EOF


if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Is this correct? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null

name="$APP_REGISTRATION"
secretname="$name"
description="Grafana OAuth secret"

echo "Create secret for ${name}"
id="$(az ad app list --filter "displayname eq '${name}'" --query [].id --output tsv)"

password="$(az ad app credential reset --id "${id}" --display-name "${secretname}" --append --query password --output tsv --only-show-errors)"
secret="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='${secretname}'], &endDateTime)[-1].{endDateTime:endDateTime,keyId:keyId}")"
secret_id="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='${secretname}'], &endDateTime)[-1].keyId")"
expiration_date="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='${secretname}'], &endDateTime)[-1].endDateTime" --output tsv)"

   
# update_app_credentials_in_az_keyvault "${secretname}" "${id}" "${password}" "${description}" "${secret_id}" ${expiration_date} "${KEYVAULT}"

# Use jq together with a credentials json template to ensure we end up with valid json, and then put the result into a tmp file which we will upload to the keyvault.
tmp_file_path="${script_dir_path}/${secretname}.json"
cat "$template_path" | jq -r \
    --arg name "${secretname}" \
    --arg id "${id}" \
    --arg password "${password}" \
    --arg description "${description}" \
    --arg tenantId "" \
    --arg secretId "${secret_id}" \
    '.name=$name | .id=$id | .password=$password | .description=$description | .tenantId=$tenantId | .secretId=$secretId' >"$tmp_file_path"

echo "Update credentials in keyvault..."
az keyvault secret set --vault-name $KEYVAULT --name "${secretname}" --file "${tmp_file_path}" --expires ${expiration_date} 2>&1 >/dev/null

# Clean up
rm -rf "$tmp_file_path"

echo "Client secret refreshed and stored in Keyvault"
