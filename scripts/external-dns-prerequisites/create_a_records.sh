#!/usr/bin/env bash

# PURPOSE
# Creates cluster specific A record and active cluster A record. Modifies active cluster A record with new IP.

# Example 1:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env MIGRATION_STRATEGY=aa CLUSTER_NAME="weekly-42" ./create_a_records.sh

# Example 2:
# RADIX_ZONE_ENV=./../radix-zone/radix_zone_dev.env MIGRATION_STRATEGY=at CLUSTER_NAME="anneli-test" ./create_a_records.sh

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file
# - CLUSTER_NAME            : Cluster name, ex: "test-2", "weekly-93"
# - MIGRATION_STRATEGY      : Is this an active or a testing cluster? Ex: "aa", "at". Default is "at".

# Optional:
# - USER_PROMPT             : Enable/disable user prompt, ex: "true" [default], "false"


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

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME." >&2
    exit 1
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "\nConnecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 1
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
verify_cluster_access


#######################################################################################

SELECTED_INGRESS_IP_RAW_ADDRESS=$(kubectl get secret --namespace "ingress-nginx" "ingress-nginx-raw-ip" -ojson | jq .data.rawIp --raw-output | base64 -d)

function createARecord() {
    local RECORD_NAME=$1
    local IP_ADDRESS=$2
    printf "Creating A record with name $RECORD_NAME and IP $IP_ADDRESS..."
    FIND_RECORD=$(az network dns record-set a show \
        --name "$RECORD_NAME" \
        --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
        --zone-name "$AZ_RESOURCE_DNS" \
        --query name \
        --output tsv \
        2>/dev/null)
    if [[ $FIND_RECORD = "" ]]; then
        # Create A record
        az network dns record-set a add-record \
            --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
            --zone-name "$AZ_RESOURCE_DNS" \
            --record-set-name "$RECORD_NAME" \
            --ipv4-address "$IP_ADDRESS" \
            --if-none-match \
            --ttl 10 \
            2>&1 >/dev/null
    else
        # Update A record
        az network dns record-set a update \
            --name "$RECORD_NAME" \
            --resource-group "$AZ_RESOURCE_GROUP_COMMON" \
            --zone-name "$AZ_RESOURCE_DNS" \
            --set aRecords[0].ipv4Address="$IP_ADDRESS" \
            2>&1 >/dev/null
    fi
}


createARecord $CLUSTER_NAME $SELECTED_INGRESS_IP_RAW_ADDRESS || \
    printf "ERROR: failed to create A record" >&2

if [ "$MIGRATION_STRATEGY" = "aa" ]; then
    old_ip=$(az network dns record-set a show --name active-cluster --zone-name $AZ_RESOURCE_DNS --resource-group $AZ_RESOURCE_GROUP_COMMON | jq .aRecords[0].ipv4Address --raw-output)
    echo -e ""
    echo -e "About to change active cluster DNS record"
    echo -e ""
    echo -e "   > WHERE:"
    echo -e "   ------------------------------------------------------------------"
    echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
    echo -e "   -  AZ_RESOURCE_DNS                  : $AZ_RESOURCE_DNS"
    echo -e ""
    echo -e "   > WHAT:"
    echo -e "   -------------------------------------------------------------------"
    echo -e "   -  RECORD_NAME                      : active-cluster"
    echo -e "   -  OLD_IP                           : $old_ip"
    echo -e "   -  NEW_IP                           : $SELECTED_INGRESS_IP_RAW_ADDRESS"
    echo -e ""
    echo -e "   > WHO:"
    echo -e "   -------------------------------------------------------------------"
    echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
    echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
    echo -e ""

    echo ""

    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -r -p "Is this correct? (Y/n) " yn
            case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 1;;
            * ) echo "Please answer yes or no.";;
            esac
        done
        echo ""
    fi

    createARecord active-cluster $SELECTED_INGRESS_IP_RAW_ADDRESS || \
      printf "ERROR: failed to create A record" >&2
fi
printf "...Done.\n"
