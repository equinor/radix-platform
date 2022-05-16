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
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env K8S_API_IP_WHITELIST="10.1.0.0/16,123.456.78.90" ./update_api_server_whitelist.sh

# Update a cluster with the list stored in keyvault (if user prompt is true, it is optional to enter a list of IPs)
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" ./update_api_server_whitelist.sh

# Update the keyvault secret and a cluster with the list
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" K8S_API_IP_WHITELIST="10.1.0.0/16,123.456.78.90" ./update_api_server_whitelist.sh

#######################################################################################
### START
###

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Define script variables

SECRET_NAME="kubernetes-api-server-whitelist-ips-${RADIX_ZONE}"
UPDATE_KEYVAULT=true

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

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
if [[ -n $CLUSTER_NAME ]]; then
    echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
fi
if [[ -n $K8S_API_IP_WHITELIST ]]; then
    echo -e "   -  K8S_API_IP_WHITELIST             : $K8S_API_IP_WHITELIST"
fi
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  SECRET_NAME                      : $SECRET_NAME"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Is this correct? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting..."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

#######################################################################################
### Get list of IPs
###

if [[ -z $K8S_API_IP_WHITELIST ]];then
    # Get secret from keyvault
    printf "Getting secret from keyvault..."
    EXISTING_K8S_API_IP_WHITELIST=$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $SECRET_NAME --query="value" -otsv 2>/dev/null)
    printf " Done.\n"
    echo "Existing list of IPs: $EXISTING_K8S_API_IP_WHITELIST"
    # Prompt to paste list.
    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -p "Do you want to update the list of IPs? (Y/n) " yn
            case $yn in
                [Yy]* ) PASTE_LIST=true; break;;
                [Nn]* ) break;;
                * ) echo "Please answer yes or no.";;
            esac
        done
        if [[ $PASTE_LIST == true ]]; then
            while true; do
                read -p "Enter the complete comma-separated list of IPs: " K8S_API_IP_WHITELIST
                case $K8S_API_IP_WHITELIST in
                    [0-9.,/]* ) break;;
                    * ) echo "Please enter a comma-separated list of IPs.";;
                esac
            done
        fi
    fi
    if [[ -z $K8S_API_IP_WHITELIST ]]; then
        UPDATE_KEYVAULT=false
        K8S_API_IP_WHITELIST=$EXISTING_K8S_API_IP_WHITELIST
        if [[ -z $K8S_API_IP_WHITELIST ]]; then
            printf " ERROR: Could not get secret \"$SECRET_NAME\" from keyvault \"$AZ_RESOURCE_KEYVAULT\". Quitting...\n" >&2
            exit 1
        fi
    fi
fi

#######################################################################################
### Update keyvault if input list
###

if [[ $UPDATE_KEYVAULT == true ]];then
    # Update keyvault
    printf "Updating keyvault \"$AZ_RESOURCE_KEYVAULT\"..."
    if [[ ""$(az keyvault secret set --name "$SECRET_NAME" --vault-name "$AZ_RESOURCE_KEYVAULT" --value "$K8S_API_IP_WHITELIST" 2>&1)"" == *"ERROR"* ]]; then
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
    if [[ -n "$(az aks list --query "[?name=='$CLUSTER_NAME'].name" --subscription $AZ_SUBSCRIPTION_ID -otsv)" ]];then
        if [[ $USER_PROMPT == true ]]; then
            echo "This will update \"$CLUSTER_NAME\" with \"$K8S_API_IP_WHITELIST\""
            while true; do
                read -p "Is this correct? (Y/n) " yn
                case $yn in
                    [Yy]* ) break;;
                    [Nn]* ) echo ""; echo "Quitting..."; exit 0;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
        fi
        # Update cluster
        printf "Updating cluster with whitelist IPs..."
        if [[ $(az aks update --resource-group $AZ_RESOURCE_GROUP_CLUSTERS --name $CLUSTER_NAME --api-server-authorized-ip-ranges "$K8S_API_IP_WHITELIST") == *"ERROR"* ]]; then
            printf "ERROR: Could not update cluster. Quitting...\n" >&2
            exit 1
        fi
        printf " Done.\n"
    else
        echo "ERROR: Could not find the cluster. Make sure you have access to it." >&2
        exit 1
    fi
fi
