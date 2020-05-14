#!/bin/bash

#######################################################################################
### PURPOSE
### 

# TODO - Bootstrap radix zone infrastructure for "playground.radix.equinor.com"


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

# TODO - RADIX_ZONE_ENV=../radix_zone_playground.env ./bootstrap.sh


#######################################################################################
### START
### 

echo ""
echo "Start bootstrap of Radix Zone... "


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"


#######################################################################################
### Read inputs and configs
###

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
echo -e "Bootstrap radix zone will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  AZ_INFRASTRUCTURE_REGION           : $AZ_INFRASTRUCTURE_REGION"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    read -p "Is this correct? (Y/n) " -n 1 -r
    if [[ "$REPLY" =~ (N|n) ]]; then
    echo ""
    echo "Quitting."
    exit 0
    fi
    echo ""
fi

#######################################################################################
### Resource groups
###

echo ""

# Note - AZ DNS Zones locations are "global", meaning you cannot set a location.
echo "Resource groups: Creating..."

az group create --location "${AZ_INFRASTRUCTURE_REGION}" --name "${AZ_RESOURCE_GROUP_CLUSTERS}" --output none
az group create --location "${AZ_INFRASTRUCTURE_REGION}" --name "${AZ_RESOURCE_GROUP_COMMON}" --output none
az group create --location "${AZ_INFRASTRUCTURE_REGION}" --name "${AZ_RESOURCE_GROUP_MONITORING}" --output none
az group create --location "${AZ_INFRASTRUCTURE_REGION}" --name "${AZ_RESOURCE_GROUP_BACKUP}" --output none
az group create --location "${AZ_INFRASTRUCTURE_REGION}" --name "${AZ_RESOURCE_GROUP_NETWORK}" --output none
az group create --location "${AZ_INFRASTRUCTURE_REGION}" --name "${AZ_RESOURCE_GROUP_NETWORK_HUB}" --output none

#######################################################################################
### HUB - NSG
###

echo ""
echo "HUB - Network security group: Creating..."

AZ_NSG_HUB_NAME="equinor-shared-nsg"
az network nsg create -g "${AZ_RESOURCE_GROUP_NETWORK_HUB}" -n ${AZ_NSG_HUB_NAME}
echo "...Done."

#######################################################################################
### HUB - Virtual network
### Based on https://docs.omnia.equinor.com/products/classic/Network/
###

echo ""
echo "HUB - VNET + AzureFirewallSubnet: Creating..."

AZ_VNET_HUB_NAME="equinor-shared-vnet"
AZ_VNET_HUB_FIREWALL_SUBNET_NAME="AzureFirewallSubnet" # contains shared firewall handling traffic from all spoke to internet

# todo: throws error second run 
# Subnet AzureFirewallSubnet is in use by /subscriptions/34528b82-d3ee-4995-8780-558d5fcd7f07/resourceGroups/S095-NE-network-hub/providers/Microsoft.Network/azureFirewalls/equinor-firewall/azureFirewallIpConfigurations/FW-config 
# and cannot be deleted. In order to delete the subnet, delete all the resources within the subnet. See aka.ms/deletesubnet.
az network vnet create -g "${AZ_RESOURCE_GROUP_NETWORK_HUB}" -n "${AZ_VNET_HUB_NAME}" --address-prefix 10.0.0.0/21

az network vnet subnet create -g "${AZ_RESOURCE_GROUP_NETWORK_HUB}" --vnet-name "${AZ_VNET_HUB_NAME}" -n "${AZ_VNET_HUB_FIREWALL_SUBNET_NAME}" \
    --address-prefixes 10.0.0.128/25

echo "...Done."

#######################################################################################
### HUB - Firewall
### Based on https://docs.microsoft.com/en-us/azure/firewall/deploy-cli
###
echo ""
echo "HUB - Firewall: Creating..."

AZ_FIREWALL_NAME=equinor-firewall
AZ_FW_PUBLIC_IP_NAME=firewall-pip

# todo: throws error second run
# Deployment failed. Correlation ID: 9af929fe-0876-495a-93f6-be5b777c4db2. Operation failed with status: 'Not Found'. 
# Details: 404 Client Error: Not Found for url: https://management.azure.com/subscriptions/34528b82-d3ee-4995-8780-558d5fcd7f07/providers/Microsoft.Network/locations/northeurope/operations/a172e6f7-78ef-4fac-a939-07e55dd76966?api-version=2019-11-01
az network firewall create -g "${AZ_RESOURCE_GROUP_NETWORK_HUB}" -n "${AZ_FIREWALL_NAME}"
az network public-ip create -g "${AZ_RESOURCE_GROUP_NETWORK_HUB}" -n "${AZ_FW_PUBLIC_IP_NAME}" --allocation-method static --sku standard
az network firewall ip-config create \
    -g "${AZ_RESOURCE_GROUP_NETWORK_HUB}" \
    -n FW-config \
    --vnet-name "${AZ_VNET_HUB_NAME}" \
    --firewall-name "${AZ_FIREWALL_NAME}" \
    --public-ip-address "${AZ_FW_PUBLIC_IP_NAME}"
az network firewall update -n "${AZ_FIREWALL_NAME}" -g "${AZ_RESOURCE_GROUP_NETWORK_HUB}"
az network public-ip show -n "${AZ_FW_PUBLIC_IP_NAME}" -g "${AZ_RESOURCE_GROUP_NETWORK_HUB}"
AZ_FIREWALL_PRIV_IP="$(az network firewall ip-config list -g ${AZ_RESOURCE_GROUP_NETWORK_HUB} -f ${AZ_FIREWALL_NAME} --query "[?name=='FW-config'].privateIpAddress" --output tsv)"
    
echo "...Done."

#######################################################################################
### HUB - Network routing table
###

echo ""

echo "HUB - Route table internet: Creating..."

AZ_HUB_ROUTE_TABLE_NAME="equinor-shared-route-table"
az network route-table create -g "${AZ_RESOURCE_GROUP_NETWORK_HUB}" -n "${AZ_HUB_ROUTE_TABLE_NAME}"

az network route-table route create -g "${AZ_RESOURCE_GROUP_NETWORK_HUB}" --route-table-name "${AZ_HUB_ROUTE_TABLE_NAME}" -n internet \
    --next-hop-type VirtualAppliance --address-prefix 0.0.0.0/0 --next-hop-ip-address ${AZ_FIREWALL_PRIV_IP}

echo "...Done."

#######################################################################################
### HUB - Other subnet
###

echo ""

echo "HUB - Other subnets: Creating..."
AZ_VNET_HUB_HUB_SUBNET_NAME="equinor-hub" # ?
AZ_VNET_HUB_SHARED_SUBNET_NAME="equinor-shared" # contains shared services as DNS
AZ_VNET_HUB_GATEWAY_SUBNET_NAME="equinor-gateway" # used for express route, probably not relevant in this setup? https://github.com/MicrosoftDocs/azure-docs/blob/master/includes/vpn-gateway-about-gwsubnet-include.md

az network vnet subnet create -g "${AZ_RESOURCE_GROUP_NETWORK_HUB}" --vnet-name "${AZ_VNET_HUB_NAME}" -n "${AZ_VNET_HUB_HUB_SUBNET_NAME}" \
    --address-prefixes 10.0.1.0/24 --network-security-group "${AZ_NSG_HUB_NAME}" --route-table "${AZ_HUB_ROUTE_TABLE_NAME}"

az network vnet subnet create -g "${AZ_RESOURCE_GROUP_NETWORK_HUB}" --vnet-name "${AZ_VNET_HUB_NAME}" -n "${AZ_VNET_HUB_SHARED_SUBNET_NAME}" \
    --address-prefixes 10.0.2.0/24 --network-security-group "${AZ_NSG_HUB_NAME}" --route-table "${AZ_HUB_ROUTE_TABLE_NAME}"

echo "...Done."

#######################################################################################
### SPOKE - Network security groups
###

echo ""
echo "Spoke - Network security group: Creating..."

AZ_NSG_SUBNET_NAME="${AZ_SUBSCRIPTION_PREFIX}-NE-subnet-nsg"
az network nsg create -g "${AZ_RESOURCE_GROUP_NETWORK}" -n ${AZ_NSG_SUBNET_NAME}

echo "...Done."

#######################################################################################
### SPOKE - Network routing table
###

echo ""

echo "Spoke - Route table internet: Creating..."

AZ_ROUTE_TABLE_NAME="${AZ_SUBSCRIPTION_PREFIX}-NE-internet-routetable"
az network route-table create -g "${AZ_RESOURCE_GROUP_NETWORK}" -n "${AZ_ROUTE_TABLE_NAME}"

az network route-table route create -g "${AZ_RESOURCE_GROUP_NETWORK}" --route-table-name "${AZ_ROUTE_TABLE_NAME}" -n internet \
    --next-hop-type VirtualAppliance --address-prefix 0.0.0.0/0 --next-hop-ip-address ${AZ_FIREWALL_PRIV_IP}

echo "...Done."


#######################################################################################
### SPOKE - Virtual Network
###

echo ""

echo "Spoke - VNET: Creating..."

## 10.0.8.0/21 = 10.0.8.0 -> 10.0.15.255
## 10.0.8.0/22 = 10.0.8.0 -> 10.0.11.255
az network vnet create -g "${AZ_RESOURCE_GROUP_NETWORK}" -n "${AZ_VNET_SPOKE_NAME}" --address-prefix 10.0.8.0/21
az network vnet subnet create -g "${AZ_RESOURCE_GROUP_NETWORK}" --vnet-name "${AZ_VNET_SPOKE_NAME}" -n "${AZ_VNET_SPOKE_SUBNET_NAME}" \
    --address-prefixes 10.0.8.0/22 --network-security-group "${AZ_NSG_SUBNET_NAME}" --route-table "${AZ_ROUTE_TABLE_NAME}" \
    --service-endpoints Microsoft.KeyVault Microsoft.Sql Microsoft.Storage

echo "...Done."

#######################################################################################
### HUB/SPOKE - Peer network
###

echo ""

echo "Peering HUB and SPOKE..."

HUB_VNET_RESOURCE_ID="$(az network vnet show --resource-group $AZ_RESOURCE_GROUP_NETWORK_HUB -n $AZ_VNET_HUB_NAME --query "id" --output tsv)"
SPOKE_VNET_RESOURCE_ID="$(az network vnet show --resource-group $AZ_RESOURCE_GROUP_NETWORK -n $AZ_VNET_SPOKE_NAME --query "id" --output tsv)"
VNET_PEERING_NAME=spoke-to-hub
HUB_PEERING_NAME=hub-to-spoke
echo "Peering spoke-vnet $AZ_VNET_SPOKE_NAME to hub-vnet $AZ_VNET_HUB_NAME... "
az network vnet peering create -g $AZ_RESOURCE_GROUP_NETWORK -n $VNET_PEERING_NAME --vnet-name $AZ_VNET_SPOKE_NAME --remote-vnet $HUB_VNET_RESOURCE_ID --allow-vnet-access
az network vnet peering create -g $AZ_RESOURCE_GROUP_NETWORK_HUB -n $HUB_PEERING_NAME --vnet-name $AZ_VNET_HUB_NAME --remote-vnet $SPOKE_VNET_RESOURCE_ID --allow-vnet-access

echo "...Done."

echo ""
echo "Bootstrap done!"
