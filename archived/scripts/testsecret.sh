#!/usr/bin/env bash


function check_secrets_exist() {
    local keyvault_name="$1"
    shift
    local keys=("$@")
    local missing_secrets=()
    
    for key in "${keys[@]}"; do
        if ! az keyvault secret show --vault-name "$keyvault_name" --name "$key" &>/dev/null; then
            missing_secrets+=("$key")
        fi
    done
    
    if [ ${#missing_secrets[@]} -gt 0 ]; then
        echo "ERROR: Missing secrets in Key Vault '$keyvault_name': ${missing_secrets[*]}" >&2
        return 1
    fi
    
    return 0
}

# Read the list from Azure App Configuration
app_config_name="radix-appconfig-c3"
config_key="base_secrets"

# Get the value from App Configuration (assumes it's a comma-separated or JSON array)
secret_list=$(az appconfig kv show --name "$app_config_name" --key "$config_key" --query "value" -o tsv 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$secret_list" ]; then
    echo "ERROR: Failed to retrieve key '$config_key' from App Configuration '$app_config_name'" >&2
    exit 1
fi

# Parse the list into an array
# If it's comma-separated:
IFS=',' read -ra secrets <<< "$secret_list"

# Or if it's a JSON array like ["secret1","secret2","secret3"]:
# mapfile -t secrets < <(echo "$secret_list" | jq -r '.[]')

check_secrets_exist "radix-keyv-c3" "${secrets[@]}"