#!/usr/bin/env bash

#######################################################################################
### PURPOSE
### 

# Bootstrap infrastructure for managing private links

#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.


#######################################################################################
### HOW TO USE
### 

# RADIX_ZONE_ENV=../radix_zone_dev.env ./bootstrap.sh

#######################################################################################
### START
### 

echo ""
echo "Start bootstrap of infrastructure for private links... "


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"

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

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi


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
echo -e "Bootstrap Private Endpoint infrastructure will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e "   -  AZ_RESOURCE_GROUP_VNET_HUB       : $AZ_RESOURCE_GROUP_VNET_HUB"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_VNET_HUB_NAME                 : $AZ_VNET_HUB_NAME"
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
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi


#######################################################################################
### Resource group
###

echo ""

# Note - 
echo "Azure resource group: Creating ${AZ_RESOURCE_GROUP_VNET_HUB}..."
az group create \
    --location "${AZ_RADIX_ZONE_LOCATION}" \
    --name "${AZ_RESOURCE_GROUP_VNET_HUB}"
echo "...Done."

#######################################################################################
### HUB VNET
### VNET containing private links to managed azure services. 

echo ""

# Note - 
echo "Azure VNET: Creating ${AZ_VNET_HUB_NAME}..."
az network vnet create \
    --resource-group "${AZ_RESOURCE_GROUP_VNET_HUB}" \
    --name "${AZ_VNET_HUB_NAME}" \
    --location "${AZ_RADIX_ZONE_LOCATION}" \
    --address-prefix 10.0.0.0/16 \
    --subnet-name "${AZ_VNET_HUB_SUBNET_NAME}" \
    --subnet-prefix 10.0.0.0/18 
echo "...Done."

#######################################################################################
### Private DNS Zone
### Used for DNS resolution for private endpoints
echo ""
echo "Azure Private DNS Zones: Creating..."

function createPrivateDNSZones(){
    dns_zone="${1}"
    DNS_ZONE_EXIST="$(az network private-dns zone show --resource-group "${AZ_RESOURCE_GROUP_VNET_HUB}" --name "${dns_zone}" --query "type" --output tsv 2>/dev/null)"
    if [[ $DNS_ZONE_EXIST != "Microsoft.Network/privateDnsZones" ]]; then
        echo "Private DNS Zone: Creating ${dns_zone}..."
        # throws error if run twice
        az network private-dns zone create --resource-group "${AZ_RESOURCE_GROUP_VNET_HUB}" --name "${dns_zone}"
    fi
    DNS_ZONE_LINK_EXIST="$(az network private-dns link vnet show --resource-group "${AZ_RESOURCE_GROUP_VNET_HUB}" --name hublink --zone-name "${dns_zone}" --query "type" --output tsv 2>/dev/null)"
    if [[ $DNS_ZONE_LINK_EXIST != "Microsoft.Network/privateDnsZones/virtualNetworkLinks" ]]; then
        echo "Linking private DNS Zone:  ${dns_zone} to HUB VNET ${AZ_VNET_HUB_NAME}"
        # throws error if run twice
        az network private-dns link vnet create --resource-group "${AZ_RESOURCE_GROUP_VNET_HUB}" --name hublink --zone-name "${dns_zone}" --virtual-network "${AZ_VNET_HUB_NAME}" --registration-enabled False
    fi  
}

for dns_zone in "${AZ_PRIVATE_DNS_ZONES[@]}"
do
    createPrivateDNSZones "${dns_zone}" &
done
wait

echo "...Done."

#######################################################################################
### END
###

echo ""
echo "Bootstrap done!"
