#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Kubernetes API server should be configured with restricted access.
# This script takes a list of IPs and updates the secret in the keyvault.
# If a cluster name is specified, then the k8s API server for the cluster will be updated.

# Default usage: Get whitelist from keyvault to pass in on cluster creation in aks bootstrap.

# Optional usage: Update the secret with a new list of IPs. Will overwrite the existing secret.
# Optional usage: Update the API whitelist of an existing cluster.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file

# Optional:
# - CLUSTER_NAME            : Name of cluster to update
# - K8S_API_IP_WHITELIST    : Comma separated list of IPs to whitelist. Example: "10.1.0.0/16,123.456.78.90"
# - USER_PROMPT             : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# Update the keyvault secret
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./update_api_server_whitelist.sh

# Update a cluster with the list stored in keyvault (if user prompt is true, it is optional to enter a list of IPs)
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" ./update_api_server_whitelist.sh

# Update the keyvault secret and a cluster with the list
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" ./update_api_server_whitelist.sh

#######################################################################################
### START
###

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

# Optional inputs

if [[ -z "${USER_PROMPT}" ]]; then
    USER_PROMPT=true
fi

# Define script variables

SECRET_NAME="kubernetes-api-server-whitelist-ips-${RADIX_ENVIRONMENT}"
UPDATE_KEYVAULT=false

#######################################################################################
### Prepare az session
###

printf "\nLogging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "${AZ_SUBSCRIPTION_ID}" >/dev/null
printf "Done.\n"

#######################################################################################
### Functions
###

function listandindex() {
    j=0

    printf "${fmt}" "    #" "Location" "IP"
    while read -r i; do
        LOCATION=$(jq -n "${i}" | jq -r .location)
        IP=$(jq -n "${i}" | jq -r .ip)
        CURRENT_K8S_API_IP_WHITELIST+=("{\"id\":\"${j}\",\"location\":\"${LOCATION}\",\"ip\":\"${IP}\"},")
        printf "${fmt}" "   (${j})" "${LOCATION}" "${IP}"
        ((j=j+1))
    done < <(printf "%s" "${MASTER_K8S_API_IP_WHITELIST}" | jq -c '.whitelist[]')
}

function listwhitelist() {
    printf "${fmt2}" "    Location" "IP"
    while read -r i; do
        LOCATION=$(jq -n "${i}" | jq -r .location)
        IP=$(jq -n "${i}" | jq -r .ip)
        printf "${fmt2}" "    ${LOCATION}" "${IP}"
    done < <(printf "%s" "${MASTER_K8S_API_IP_WHITELIST}" | jq -c '.whitelist[]')
}

function addwhitelist() {
    while read -r i; do
        LOCATION=$(jq -n "${i}" | jq -r .location)
        IP=$(jq -n "${i}" | jq -r .ip)
        CURRENT_K8S_API_IP_WHITELIST+=("{\"location\":\"${LOCATION}\",\"ip\":\"${IP}\"},")
    done < <(printf "%s" "${MASTER_K8S_API_IP_WHITELIST}" | jq -c '.whitelist[]')
}

#######################################################################################
### Prepare K8S API IP WHITELIST
###
MASTER_K8S_API_IP_WHITELIST=$(az keyvault secret show --vault-name "${AZ_RESOURCE_KEYVAULT}" --name "${SECRET_NAME}" --query="value" -otsv | base64 --decode | jq '{whitelist:.whitelist | sort_by(.location | ascii_downcase)}' 2>/dev/null)
CURRENT_K8S_API_IP_WHITELIST=()
i=0
fmt="%-8s%-33s%-12s\n"
fmt2="%-41s%-45s\n"

# if [[ "${OSTYPE}" == "linux-gnu"* ]]; then
#     checkpackage=$( dpkg -s libnet-ip-perl /dev/null 2>&1 | grep Status: )
#     if [[ -n ${checkpackage} ]]; then
# fi

while true; do
    printf "\nCurrent k8s API whitelist server configuration:"
    printf "\n"
    printf "\n   > WHERE:"
    printf "\n   ------------------------------------------------------------------"
    printf "\n   -  RADIX_ZONE                       : %s" "${RADIX_ZONE}"
    printf "\n   -  AZ_RADIX_ZONE_LOCATION           : %s" "${AZ_RADIX_ZONE_LOCATION}"
    printf "\n   -  AZ_RESOURCE_KEYVAULT             : %s" "${AZ_RESOURCE_KEYVAULT}"
    printf "\n   -  SECRET_NAME                      : %s" "${SECRET_NAME}"
    printf "\n"
    printf "\n   Please inspect and approve the listed network before your continue:"
    printf "\n"
    CURRENT_K8S_API_IP_WHITELIST=("{ \"whitelist\": [ ")
    listandindex
    CURRENT_K8S_API_IP_WHITELIST+=("{\"id\":\"99\",\"location\":\"dummy\",\"ip\":\"0.0.0.0/32\"} ] }")
    while true; do
        printf "\n"
        read -r -p "Is above list correct? (Y/n) " yn
        case ${yn} in
        [Yy]*)
            whitelist_ok=true
            break
            ;;
        [Nn]*)
            whitelist_ok=false
            break
            ;;
        *) printf "\nPlease answer yes or no.\n" ;;
        esac
    done

    if [[ ${whitelist_ok} == false ]]; then
        while true; do
            printf "\n"
            read -r -p "Please press 'a' to add or 'd' to delete entry (a/d) " adc
            case ${adc} in
            [Aa]*)
                addip=true
                removeip=false
                break
                ;;
            [Dd]*)
                removeip=true
                addip=false
                break
                ;;
            [Cc]*) break ;;
            *) printf "\nPlease press 'a' or 'd' (Hit 'C' to cancel any updates).\n" ;;
            esac
        done
    elif [[ ${whitelist_ok} == true ]] && [[ -z ${CLUSTER_NAME} ]]; then
        printf "\nNothing to do...\n"
        exit
    fi

    if [[ ${addip} == true ]]; then
        while [ -z "${new_location}" ]; do
            printf "\nEnter location: "
            read -r new_location
        done

        while [ -z "${new_ip}" ]; do
            printf "\nEnter ip address in x.x.x.x/y format: "
            read -r new_ip
        done

        printf "\nAdding location %s at %s... " "${new_location}" "${new_ip}"
        CURRENT_K8S_API_IP_WHITELIST=("{ \"whitelist\": [ ")
        addwhitelist
        UPDATE_KEYVAULT=true
        CURRENT_K8S_API_IP_WHITELIST+=("{\"location\":\"${new_location}\",\"ip\":\"${new_ip}\"}")
        CURRENT_K8S_API_IP_WHITELIST+=(" ] }")
        MASTER_K8S_API_IP_WHITELIST=$(jq <<<"${CURRENT_K8S_API_IP_WHITELIST[@]}" | jq '.' | jq 'del(.whitelist [] | select(.id == "99"))')
        printf "Done.\n"
    fi

    if [[ ${removeip} == true ]]; then
        printf "\nEnter location number of which you want to remove: "

        while [ -z "${delete_ip}" ]; do
            read -r delete_ip
        done

        MASTER_K8S_API_IP_WHITELIST=$(jq <<<"${CURRENT_K8S_API_IP_WHITELIST[@]}" | jq '.' | jq "del(.whitelist [] | select(.id == \"${delete_ip}\"))" | jq 'del(.whitelist [] | select(.id == "99"))')
        UPDATE_KEYVAULT=true
    fi

    if [[ ${whitelist_ok} == true ]]; then
        break
    else
        printf "\n"
        while true; do
            read -r -p "Are you finished with list and update Azure? (Y/n) " yn
            case ${yn} in
            [Yy]*)
                finished_ok=true
                break
                ;;
            [Nn]*)
                whitelist_ok=false
                unset delete_ip
                unset new_location
                unset new_ip
                break
                ;;
            *) printf "\nPlease answer yes or no." ;;
            esac
        done
        if [[ ${finished_ok} == true ]]; then
            break
        fi

    fi
done

MASTER_K8S_API_IP_WHITELIST_BASE64=$(jq <<<"${MASTER_K8S_API_IP_WHITELIST[@]}" | jq '{whitelist:[.whitelist[] | {location,ip}]}' | base64)

#######################################################################################
### Get list of IPs
###

K8S_API_IP_WHITELIST=$(jq <<<"${MASTER_K8S_API_IP_WHITELIST[@]}" | jq -r '[.whitelist[].ip] | join(",")')

#######################################################################################
### Update keyvault if input list
###

if [[ ${UPDATE_KEYVAULT} == true ]]; then
    # Update keyvault
    printf "\nUpdating keyvault \"%s\"... " "${AZ_RESOURCE_KEYVAULT}"
    if [[ "$(az keyvault secret set --name "${SECRET_NAME}" --vault-name "${AZ_RESOURCE_KEYVAULT}" --value "${MASTER_K8S_API_IP_WHITELIST_BASE64}" 2>&1)" == *"ERROR"* ]]; then
        printf "\nERROR: Could not update secret in keyvault \"%s\". Exiting..." "${AZ_RESOURCE_KEYVAULT}" >&2
        exit 1
    fi
    printf "Done.\n"
fi

#######################################################################################
### Update cluster
###

if [[ -n ${CLUSTER_NAME} ]]; then
    # Check if cluster exists
    printf "\nUpdate cluster \"%s\".\n" "${CLUSTER_NAME}"
    if [[ -n "$(az aks list --query "[?name=='${CLUSTER_NAME}'].name" --subscription "${AZ_SUBSCRIPTION_ID}" -otsv)" ]]; then
        printf "\nUpdating cluster with whitelist IPs...\n"
        if [[ $(az aks update --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" --name "${CLUSTER_NAME}" --api-server-authorized-ip-ranges "${K8S_API_IP_WHITELIST}") == *"ERROR"* ]]; then
            printf "ERROR: Could not update cluster. Quitting...\n" >&2
            exit 1
        fi
        printf "\nDone.\n"
    else
        printf "\nERROR: Could not find the cluster. Make sure you have access to it." >&2
        exit 1
    fi
fi
