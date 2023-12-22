#!/usr/bin/env bash

function create_monitoring_service_principal() {

    local name        # Input 1
    local description # Input 2, optional
    local password
    local id

    name="$1"
    description="$2"

    echo "Working on ${name}: Creating service principal..."

    # Skip creation if the sp exist
    local testSP
    testSP="$(az ad sp list --display-name "${name}" --query [].id --output tsv 2>/dev/null)"
    if [ -z "$testSP" ]; then
        echo "creating ${name}..."
        password="$(az ad sp create-for-rbac --name "${name}" --query password --output tsv)"
        id="$(az ad sp list --display-name "${name}" --query [].id --output tsv)"
        secret="$(az ad sp credential list --id "${id}" --query "sort_by([?displayName=='rbac'], &endDateTime)[-1:].{endDateTime:endDateTime,keyId:keyId}")"
        secret_id="$(echo "${secret}" | jq -r .[].keyId)"
        expiration_date="$(echo "${secret}" | jq -r .[].endDateTime | sed 's/\..*//')"
        printf " Done.\n"

        echo "Update credentials in keyvault..."
        update_app_credentials_in_az_keyvault "${name}" "${id}" "${password}" "${description}" "${secret_id}" "${expiration_date}" "${AZ_RESOURCE_MON_KEYVAULT}"
    else
        printf "%s exists.\n" "${name}"
    fi

    echo "Update owners of app registration...."
    update_ad_app_owners "${name}"

    echo "Update owners of service principal..."
    update_service_principal_owners "${name}"

    echo "Update additional SP info..."
    id="$(az ad sp list --display-name "${name}" --query [].id --output tsv)"
    echo "This id ${id} and description: ${description}"
    az ad sp update --id "${id}" --set notes="${description}"

    echo "Done."
}

function create_monitoring_ar_secret() {
    local name        # Input 1
    local secretname  # Input 2
    local description # Input 3, optional

    name="$1"
    secretname="$2"
    description="$3"

    echo "Create secret for ${name}"
    id="$(az ad app list --filter "displayname eq '${name}'" --query [].id --output tsv)"

    password="$(
        az ad app credential reset \
            --id "${id}" \
            --display-name "${secretname}" \
            --append --query password \
            --output tsv \
            --only-show-errors
    )"

    secret="$(
        az ad app credential list \
            --id "${id}" \
            --query "sort_by([?displayName=='${secretname}'], &endDateTime)[-1].{endDateTime:endDateTime,keyId:keyId}"
    )"

    secret_id="$(
        az ad app credential list \
            --id "${id}" \
            --query "sort_by([?displayName=='${secretname}'], &endDateTime)[-1].keyId"
    )"

    expiration_date="$(
        az ad app credential list \
            --id "${id}" \
            --query "sort_by([?displayName=='${secretname}'], &endDateTime)[-1].endDateTime" \
            --output tsv
    )"

    echo "Update credentials in keyvault..."
    update_app_credentials_in_az_keyvault "${secretname}" "${id}" "${password}" "${description}" "${secret_id}" ${expiration_date} "${AZ_RESOURCE_MON_KEYVAULT}"
}
