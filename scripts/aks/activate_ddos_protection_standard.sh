#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Active DDoS Protection Standard on scope of an AKS cluster's vnet, including it's Azure Load Balancers and associated public IPs

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Keep name short due to Azure weirdness. Ex: "test-2", "weekly-93".

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_c2.env CLUSTER_NAME=some-c2-cluster ./activate_ddos_protection_standard.sh

# If you want to test applying DDoS Protection Standard to a non-standard subscription, like a weekly cluster, set the DDOS_PROTECTION_STANDARD_RESOURCE_ID_OVERRIDE environment variable
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env DDOS_PROTECTION_STANDARD_RESOURCE_ID_OVERRIDE=/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/rg-protection-we/providers/Microsoft.Network/ddosProtectionPlans/ddos-protection CLUSTER_NAME=beastmode-11 ./activate_ddos_protection_standard.sh

#######################################################################################
### START
###

#######################################################################################
### Read inputs and configs
###

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
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

if [[ -n "$DDOS_PROTECTION_STANDARD_RESOURCE_ID_OVERRIDE" ]]; then
    DDOS_PROTECTION_STANDARD_RESOURCE_ID="$DDOS_PROTECTION_STANDARD_RESOURCE_ID_OVERRIDE"
fi

if [[ -z "$DDOS_PROTECTION_STANDARD_RESOURCE_ID" ]]; then
    echo "ERROR: Please specify DDOS_PROTECTION_STANDARD_RESOURCE_ID in ${RADIX_ZONE_ENV} or pass DDOS_PROTECTION_STANDARD_RESOURCE_ID_OVERRIDE env variable to script" >&2
    exit 1
fi

# Read the cluster config that correnspond to selected environment in the zone config.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/${CLUSTER_TYPE}.env"

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh


# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Bootstrap AKS will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                           : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION               : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                    : $RADIX_ENVIRONMENT"
echo -e "   -  AZ_RESOURCE_GROUP_CLUSTERS           : $AZ_RESOURCE_GROUP_CLUSTERS"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  CLUSTER_NAME                         : $CLUSTER_NAME"
echo -e "   -  VNET_NAME                            : $VNET_NAME"
echo -e "   -  DDOS_PROTECTION_STANDARD_RESOURCE_ID : $DDOS_PROTECTION_STANDARD_RESOURCE_ID"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                      : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                              : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -r -p "Is this correct? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            echo ""
            echo "Quitting."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    echo ""
fi

echo ""

if [[ "$RADIX_ZONE" != "c2" ]]; then
    while true; do
        read -r -p "Selected RADIX_ZONE is ${RADIX_ZONE}, which is _NOT_ c2. Is this correct? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            echo ""
            echo "Quitting."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    echo ""
fi

echo "Adding ${VNET_NAME} to list of vnets protected by ${DDOS_PROTECTION_STANDARD_RESOURCE_ID}..."

az network vnet update --ddos-protection "true" --ddos-protection-plan ${DDOS_PROTECTION_STANDARD_RESOURCE_ID} --resource-group ${AZ_RESOURCE_GROUP_CLUSTERS} --name ${VNET_NAME}

echo ""
echo "Done.\n"