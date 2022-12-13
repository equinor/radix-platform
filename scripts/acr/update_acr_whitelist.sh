#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# ACR should be configured with restricted access.
# This script let's you interactively modify a list of whitelisted IPs in our key vault and optionally apply this list as ACR network rules.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file

# Optional:
# - USER_PROMPT             : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./update_acr_whitelist.sh

# Add a single IP-mask to existing network rules
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env IP_MASK=10.0.0.2/31 IP_LOCATION=test-location ACTION=add ./update_acr_whitelist.sh

# Delete a single IP-mask to existing network rules
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env IP_MASK=10.0.0.2/31 ACTION=delete ./update_acr_whitelist.sh

#######################################################################################
### START
###

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

hash uuidgen 2>/dev/null || {
    echo -e "\nERROR: uuidgen not found in PATH. Exiting..." >&2
    exit 1
}

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "${RADIX_ZONE_ENV}" ]]; then
    printf "\nERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "${RADIX_ZONE_ENV}" ]]; then
        printf "\nERROR: RADIX_ZONE_ENV=%s is invalid, the file does not exist." "${RADIX_ZONE_ENV}" >&2
        exit 1
    fi
    source "${RADIX_ZONE_ENV}"
fi

if [[ -n "${IP_MASK}" ]]; then
    if [[ "${ACTION}" != "add" && "${ACTION}" != "delete" ]]; then
        printf "\nERROR: ACTION must be either 'add' or 'delete'." >&2
        exit 1
    fi
    if [[ -z "${IP_LOCATION}" ]] && [[ "${ACTION}" == "add" ]]; then
        printf "\nERROR: IP_MASK can not be used without IP_LOCATION when adding an entry." >&2
        exit 1
    fi
fi

if [[ -n "${IP_LOCATION}" ]]; then
    if [[ -z "${IP_MASK}" ]]; then
        printf "\nERROR: IP_LOCATION can not be used without IP_MASK" >&2
        exit 1
    fi
fi

# Optional inputs

if [[ -z "${USER_PROMPT}" ]]; then
    USER_PROMPT=true
fi

# Define script variables

SECRET_NAME="acr-whitelist-ips-${RADIX_ENVIRONMENT}"
update_keyvault=false

#######################################################################################
### Prepare az session
###

printf "\nLogging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "${AZ_SUBSCRIPTION_ID}" >/dev/null
printf "Done.\n"

#######################################################################################
### Import lib
###

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/lib_ip_whitelist.sh

#######################################################################################
### Fetch ACR IP whitelist from key vault
###
MASTER_ACR_IP_WHITELIST=$(az keyvault secret show --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${SECRET_NAME}" --query="value" -otsv | base64 --decode | jq '{whitelist:.whitelist | sort_by(.location | ascii_downcase)}' 2>/dev/null)

#######################################################################################
### Run interactive wizard to modify IP whitelist
###

MASTER_ACR_IP_WHITELIST=$(az keyvault secret show --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${SECRET_NAME}" --query="value" -otsv | base64 --decode | jq '{whitelist:.whitelist | sort_by(.location | ascii_downcase)}' 2>/dev/null)
temp_file_path="/tmp/$(uuidgen)"

if [[ -n "${IP_MASK}" ]]; then
    if [[ "${ACTION}" == "add" ]]; then
        add-single-ip-to-whitelist "${MASTER_ACR_IP_WHITELIST}" "${temp_file_path}" "${IP_MASK}" "${IP_LOCATION}"
    else
        delete-single-ip-from-whitelist "${MASTER_ACR_IP_WHITELIST}" "${temp_file_path}" "${IP_MASK}"
    fi
else
    run-interactive-ip-whitelist-wizard "${MASTER_ACR_IP_WHITELIST}" "${temp_file_path}"
fi
new_master_acr_ip_whitelist_base64=$(cat ${temp_file_path})
new_master_acr_ip_whitelist=$(echo ${new_master_acr_ip_whitelist_base64} | base64 -d)

#######################################################################################
### Calculate which IPs are to be removed, and which IPs are to be added
###

desired_ips_file="/tmp/$(uuidgen)"
current_ips_file="/tmp/$(uuidgen)"
current_ips_file_no_mask="/tmp/$(uuidgen)"
current_ips_file_with_duplicates="/tmp/$(uuidgen)"
jq <<<"${new_master_acr_ip_whitelist[@]}" | jq -r '[.whitelist[].ip] | join("\n")' | sort | uniq > ${desired_ips_file}
az acr network-rule list --name ${AZ_RESOURCE_CONTAINER_REGISTRY} | jq -r '[.ipRules[].ipAddressOrRange] | join("\n")' > ${current_ips_file_no_mask}
cat ${current_ips_file_no_mask} | grep -v "/" | xargs -I {} echo "{}/32" >> ${current_ips_file_with_duplicates}
cat ${current_ips_file_no_mask} | grep "/" >> ${current_ips_file_with_duplicates}
cat ${current_ips_file_with_duplicates} | sort | uniq > ${current_ips_file}
ips_to_remove=$(comm -23 <(sort ${current_ips_file}) <(sort ${desired_ips_file}))
ips_to_add=$(comm -23 <(sort ${desired_ips_file}) <(sort ${current_ips_file}))

# clean up temp files
rm $desired_ips_file $current_ips_file $current_ips_file_no_mask $current_ips_file_with_duplicates $temp_file_path

#######################################################################################
### Update keyvault with new whitelist
###

function update-keyvault() {
    printf "\nUpdating keyvault \"%s\"... " "${AZ_RESOURCE_KEYVAULT}"
    if [[ "$(az keyvault secret set --name "${SECRET_NAME}" --vault-name "${AZ_RESOURCE_KEYVAULT}" --value "${new_master_acr_ip_whitelist_base64}" 2>&1)" == *"ERROR"* ]]; then
        printf "\nERROR: Could not update secret in keyvault \"%s\". Exiting..." "${AZ_RESOURCE_KEYVAULT}" >&2
        exit 1
    fi
    printf "Done.\n"
}

if [[ $(echo "${ips_to_add}${ips_to_remove}" | wc -c) -le 1 ]]; then
    printf "No changes to apply to ACR whitelist.\n"
    update-keyvault
    printf "Done.\n"
    exit 0
fi

#######################################################################################
### Update ACR with new whitelist
###

printf "\nUpdating ACR ${AZ_RESOURCE_CONTAINER_REGISTRY}...\n\n"

if [[ $USER_PROMPT == true ]]; then
    while true; do
        printf "Deleting these IPs\n${ips_to_remove}\n\n"
        printf "Adding these IPs\n${ips_to_add}\n\n"
        read -r -p "Proceed with operation? (Y/n) " yn
        case ${yn} in
        [Yy]*)
            whitelist_ok=true
            break
            ;;
        [Nn]*)
            whitelist_ok=false
            exit 1
            ;;
        *) printf "\nPlease answer yes or no.\n" ;;
        esac
    done
fi

update-keyvault

for ip_to_add in ${ips_to_add}; do
    printf "Adding ${ip_to_add} to ACR whitelist...\n"
    az acr network-rule add --ip-address "${ip_to_add}" --name ${AZ_RESOURCE_CONTAINER_REGISTRY} --resource-group ${AZ_RESOURCE_GROUP_COMMON} >/dev/null
done

for ip_to_remove in ${ips_to_remove}; do
    printf "Deleting ${ip_to_remove} from ACR whitelist...\n"
    ip_to_remove_no_32_mask=${ip_to_remove%"/32"}
    az acr network-rule remove --ip-address "${ip_to_remove_no_32_mask}" --name ${AZ_RESOURCE_CONTAINER_REGISTRY} --resource-group ${AZ_RESOURCE_GROUP_COMMON} >/dev/null
done

printf "Done.\n"
