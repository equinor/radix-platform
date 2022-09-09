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
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "ERROR: RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Define script variables

SECRET_NAME="kubernetes-api-server-whitelist-ips-${RADIX_ENVIRONMENT}"
UPDATE_KEYVAULT=false





#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Functions
###

function listandindex() {
    j=0
    
    printf "$fmt" "    nr" "Location" "IP"
    while read -r i; do
        LOCATION=$(jq -n "$i" | jq -r .location)
        IP=$(jq -n "$i" | jq -r .ip)
        CURRENT_K8S_API_IP_WHITELIST+=("{\"id\":\"$j\",\"location\":\"$LOCATION\",\"ip\":\"$IP\"},")
        printf "$fmt" "   ($j)" "$LOCATION" "$IP"
        ((j=j+1))
    done < <(echo "${MASTER_K8S_API_IP_WHITELIST}" | jq -c '.whitelist[]')
}

function listwhitelist() {
    printf "$fmt2" "    Location" "IP"
    while read -r i; do
        LOCATION=$(jq -n "$i" | jq -r .location)
        IP=$(jq -n "$i" | jq -r .ip)
        printf "$fmt2" "    $LOCATION" "$IP"
    done < <(echo "${MASTER_K8S_API_IP_WHITELIST}" | jq -c '.whitelist[]')
}

function addwhitelist() {
    while read -r i; do
        LOCATION=$(jq -n "$i" | jq -r .location)
        IP=$(jq -n "$i" | jq -r .ip)
        CURRENT_K8S_API_IP_WHITELIST+=("{\"location\":\"$LOCATION\",\"ip\":\"$IP\"},")
    done < <(echo "${MASTER_K8S_API_IP_WHITELIST}" | jq -c '.whitelist[]')

}


#######################################################################################
### Prepare K8S API IP WHITELIST
###
MASTER_K8S_API_IP_WHITELIST=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name "$SECRET_NAME" --query="value" -otsv | base64 --decode | jq '{whitelist:.whitelist | sort_by(.location | ascii_downcase)}' 2>/dev/null)
CURRENT_K8S_API_IP_WHITELIST=()
i=0
fmt="%-8s%-33s%-12s\n"
fmt2="%-41s%-45s\n"
f2=" %9s"
# if [[ "$OSTYPE" == "linux-gnu"* ]]; then
#     checkpackage=$( dpkg -s libnet-ip-perl /dev/null 2>&1 | grep Status: )
#     if [[ -n $checkpackage ]]; then
# fi
while true; do
        echo -e ""
        echo -e "Current k8s API whitelist server configuration:"
        echo -e ""
        echo -e "   > WHERE:"
        echo -e "   ------------------------------------------------------------------"
        echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
        echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
        echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
        echo -e "   -  SECRET_NAME                      : $SECRET_NAME"
        echo -e "   ------------------------------------------------------------------"
        echo -e "   Please inspect and approve the listed network before your continue"
        echo -e ""
        CURRENT_K8S_API_IP_WHITELIST=("{ \"whitelist\": [ ")
        listandindex
        CURRENT_K8S_API_IP_WHITELIST+=("{\"id\":\"99\",\"location\":\"dummy\",\"ip\":\"0.0.0.0/32\"} ] }")
        echo -e "   ------------------------------------------------------------------"
        echo ""
        while true; do
            read -r -p "Is above list correct? (Y/n) " yn
            case $yn in
                [Yy]* ) whitelist_ok=true; break;;
                [Nn]* ) whitelist_ok=false; break;;
                * ) echo "Please answer yes or no.";;
            esac
        done


        if [[ $whitelist_ok == false ]]; then
            while true; do
                read -r -p "Please press 'a' to add or 'd' to delete entry (a/d) " adc
                case $adc in
                    [Aa]* ) addip=true;removeip=false; break;;
                    [Dd]* ) removeip=true;addip=false; break;;
                    [Cc]* ) break;;
                    * ) echo "Please press 'a' or 'd' (Hit 'C' to cancel any updates).";;
                esac
            done
        elif [[ $whitelist_ok == true ]] && [[ -z $CLUSTER_NAME ]]; then
            echo "Nothing to do..."
            exit

        fi

        if [[ $addip == true ]]; then
            echo "Enter location:"
            read new_location
            echo "Enter ip address in x.x.x.x/y format:"
            read new_ip
            echo "Adding location $new_location at $new_ip"
            CURRENT_K8S_API_IP_WHITELIST=("{ \"whitelist\": [ ")
            addwhitelist
            UPDATE_KEYVAULT=true
            CURRENT_K8S_API_IP_WHITELIST+=("{\"location\":\"$new_location\",\"ip\":\"$new_ip\"}")
            CURRENT_K8S_API_IP_WHITELIST+=(" ] }")
            MASTER_K8S_API_IP_WHITELIST=$(jq <<< ${CURRENT_K8S_API_IP_WHITELIST[@]} | jq '.' | jq 'del(.whitelist [] | select(.id == "99"))')
        fi

        if [[ $removeip == true ]]; then
            echo "Enter location number of which you want to remove:"
            read delete_ip
            MASTER_K8S_API_IP_WHITELIST=$(jq <<< ${CURRENT_K8S_API_IP_WHITELIST[@]} | jq '.' | jq 'del(.whitelist [] | select(.id == "'$delete_ip'"))' | jq 'del(.whitelist [] | select(.id == "99"))')
            UPDATE_KEYVAULT=true
        fi
        if [[ $whitelist_ok == true ]]; then
            break
        else
            read -r -p "Are you finished with list and update Azure? (Y/n) " y
                case $y in
                    [Yy]* ) break;;
                    #[Nn]* ) whitelist_ok=false; break;;
                    * ) echo "Please answer yes or no.";;
                esac
        fi
done


MASTER_K8S_API_IP_WHITELIST_BASE64=$(jq <<< ${MASTER_K8S_API_IP_WHITELIST[@]} | jq '{whitelist:[.whitelist[] | {location,ip}]}' | base64) 

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Update k8s API server whitelist will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
listwhitelist
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  SECRET_NAME                      : $SECRET_NAME"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

#######################################################################################
### Get list of IPs
###

K8S_API_IP_WHITELIST=$(jq <<< ${MASTER_K8S_API_IP_WHITELIST[@]} | jq -r '[.whitelist[].ip] | join(",")') 


# if [[ -z $K8S_API_IP_WHITELIST ]];then
#     # Get secret from keyvault
#     printf "Getting secret from keyvault..."
#     EXISTING_K8S_API_IP_WHITELIST=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name "$SECRET_NAME" --query="value" -otsv 2>/dev/null)
#     printf " Done.\n"
#     echo "Existing list of IPs: $EXISTING_K8S_API_IP_WHITELIST"
#     # Prompt to paste list.
#     if [[ $USER_PROMPT == true ]]; then
#         while true; do
#             read -r -p "Do you want to update the list of IPs? (Y/n) " yn
#             case $yn in
#                 [Yy]* ) PASTE_LIST=true; break;;
#                 [Nn]* ) break;;
#                 * ) echo "Please answer yes or no.";;
#             esac
#         done
#         if [[ $PASTE_LIST == true ]]; then
#             while true; do
#                 read -r -p "Enter the complete comma-separated list of IPs: " K8S_API_IP_WHITELIST
#                 case $K8S_API_IP_WHITELIST in
#                     [0-9.,/]* ) break;;
#                     * ) echo "Please enter a comma-separated list of IPs.";;
#                 esac
#             done
#         fi
#     fi
#     if [[ -z $K8S_API_IP_WHITELIST ]]; then
#         UPDATE_KEYVAULT=false
#         K8S_API_IP_WHITELIST=$EXISTING_K8S_API_IP_WHITELIST
#         if [[ -z $K8S_API_IP_WHITELIST ]]; then
#             printf " ERROR: Could not get secret \"%s\" from keyvault \"%s\". Quitting...\n" "$SECRET_NAME" "$AZ_RESOURCE_KEYVAULT" >&2
#             exit 1
#         fi
#     fi
# fi

#######################################################################################
### Update keyvault if input list
###

if [[ $UPDATE_KEYVAULT == true ]];then
    # Update keyvault
    printf "Updating keyvault \"%s\"..." "$AZ_RESOURCE_KEYVAULT"
    if [[ ""$(az keyvault secret set --name "$SECRET_NAME" --vault-name "$AZ_RESOURCE_KEYVAULT" --value "$MASTER_K8S_API_IP_WHITELIST_BASE64" 2>&1)"" == *"ERROR"* ]]; then
        echo -e "\nERROR: Could not update secret in keyvault \"$AZ_RESOURCE_KEYVAULT\". Exiting..." >&2
        exit 1
    fi
    printf " Done.\n"
fi

#######################################################################################
### Update cluster
###

if [[ -n $CLUSTER_NAME ]]; then
    # Check if cluster exists
    echo "Update cluster \"$CLUSTER_NAME\"."
    if [[ -n "$(az aks list --query "[?name=='$CLUSTER_NAME'].name" --subscription "$AZ_SUBSCRIPTION_ID" -otsv)" ]];then
        if [[ $USER_PROMPT == true ]]; then
            echo "This will update \"$CLUSTER_NAME\" with \"$K8S_API_IP_WHITELIST\""
            while true; do
                read -r -p "Is this correct? (Y/n) " yn
                case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) echo ""; echo "Quitting..."; exit 0;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
        fi
        # Update cluster
        printf "Updating cluster with whitelist IPs..."
        if [[ $(az aks update --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME" --api-server-authorized-ip-ranges "$K8S_API_IP_WHITELIST") == *"ERROR"* ]]; then
            printf "ERROR: Could not update cluster. Quitting...\n" >&2
            exit 1
        fi
        printf " Done.\n"
    else
        echo "ERROR: Could not find the cluster. Make sure you have access to it." >&2
        exit 1
    fi
fi
