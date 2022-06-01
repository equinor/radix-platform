#!/usr/bin/env bash

# upsert_password_secret generates a new cryptographically random secret/password
# and stores it in a Azure Key Vault secret
#
# Parameters:
# - Key vault name. Required
# - Secret name in Key Vault. Required
# - Overwrite if exist. Optional, true/false, default false

generate_password_and_store() {
    local keyvault=$1
    local secretName=$2
    local overwrite=$3

    if [[ -z "$keyvault" ]]; then
        >&2 printf "ERROR: Missing parameter #1 - key vault name.\n"
        return 1
    fi

    if [[ -z "$secretName" ]]; then
        >&2 printf "ERROR: Missing parameter #2 - secret name.\n"
        return 1
    fi

    case $overwrite in
        true|false) ;;
        *)
            >&2 printf "ERROR: Invalid value for parameter #3 - overwrite - must be true or false.\n"
            return 1
            ;;
    esac

    printf "Checking access to secret '$secretName' in '$keyvault'.\n"
    az keyvault secret show --vault-name $keyvault --name $secretName --output none 2> error.txt
    status=$?

    if [[ $status -eq 0 && $overwrite == false ]]; then
        printf "Secret '${secretName}' in '${keyvault}' exists, skipping update.\n"
        rm -f error.txt
        return 0
    fi

    # az cli returns exit code 3 when secret does not exist.
    # If exit code is not 3 then something else went wrong (e.g. auth or invalid secret name) and we stop the script
    if [[ $status -gt 0 && $status -ne 3 ]]; then
        >&2 printf "ERROR: $(cat error.txt)\n"
        rm -f error.txt
        return 1
    fi

    rm -f error.txt

    local password=$(python3 -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())') ||
        { echo "ERROR: Could not generate password." >&2; return 1; }

    az keyvault secret set --vault-name $keyvault --name $secretName --value $password --output none --only-show-errors ||
        { echo "ERROR: Could not get secret '$secretName' in '${keyvault}'." >&2; return 1; }

    printf "Successfully updated secret '${secretName}' in '${keyvault}'.\n"
}

create_or_update_sql_user() {
    local serverName=$1
    local connectLoginName=$2 # A SQL login with permissions to manager logins and users
    local connectPassword=$3 # Password for $connectLoginName
    local databaseName=$4 # Database name where user should be created
    local userName=$5 # Database user name to map to login
    local password=$6 # Password to set for $loginName
    local roles=$7 # Comma separated list of database role names to add the user to
    local script_dir_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

    if [[ -z $serverName ]]; then
        echo "ERROR: serverName not set" >&2
        return 1
    fi

    if [[ -z $connectLoginName ]]; then
        echo "ERROR: connectLoginName not set" >&2
        return 1
    fi

    if [[ -z $databaseName ]]; then
        echo "ERROR: databaseName not set" >&2
        return 1
    fi

    if [[ -z $userName ]]; then
        echo "ERROR: userName not set" >&2
        return 1
    fi

    if [[ -z $password ]]; then
        echo "ERROR: password not set" >&2
        return 1
    fi

    userName=$userName password=$password roles=$roles sqlcmd -b \
        -S $serverName \
        -d $databaseName \
        -U $connectLoginName \
        -P $connectPassword \
        -i "${script_dir_path}/create_or_update_user.sql" \
        || { echo "ERROR: Could not update SQL user." >&2; return 1; }
}