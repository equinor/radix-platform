#!/bin/bash


#######################################################################################
### PURPOSE
### 

# Tear down of a aks cluster and any related infrastructure (vnet and similar) or configuration that was created to specifically support that cluster.


#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        :

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.
# - CREDENTIALS_FILE    : Path to credentials in the form of shell vars. See "Set credentials" for required key/value pairs. 


#######################################################################################
### HOW TO USE
### 

# RADIX_ZONE_ENV=../radix-zone/radix_zone_us.env CLUSTER_NAME=beastmode-11 ./teardown.sh



#######################################################################################
### START
### 

echo ""
echo "Start teardown of aks instance... "


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nError: kubectl not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"

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

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Read the cluster config that correnspond to selected environment in the zone config.
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/${RADIX_ENVIRONMENT}.env"

# Optional inputs
if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

if [[ -z "$HUB_PEERING_NAME" ]]; then
    HUB_PEERING_NAME=hub-to-${CLUSTER_NAME}
fi

if [[ -z "$VNET_DNS_LINK" ]]; then
    VNET_DNS_LINK=$CLUSTER_NAME-link
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION" >/dev/null
printf "Done.\n"


#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Teardown will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $AZ_SUBSCRIPTION"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo -e ""

if [[ $USER_PROMPT == true ]]; then
    read -p "Is this correct? (Y/n) " -n 1 -r
    if [[ "$REPLY" =~ (N|n) ]]; then
    echo ""
    echo "Quitting."
    exit 0
    fi
    echo ""
fi

echo ""
echo ""


#######################################################################################
### TODO: delete replyUrls
###

# Use ingress host name to filter AAD app replyUrl list.


#######################################################################################
### Delete cluster
###

printf "Verifying that cluster exist and/or the user can access it... "
# We use az aks get-credentials to test if both the cluster exist and if the user has access to it. 
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME" 2>&1)"" == *"ERROR"* ]]; then    
    echo -e "Error: Cluster \"$CLUSTER_NAME\" not found, or you do not have access to it." >&2
    exit 0        
fi
printf "Done.\n"

echo "Deleting cluster... "
az aks delete --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$CLUSTER_NAME" --yes 2>&1 >/dev/null
echo "Done."


#######################################################################################
### Delete related stuff
###

echo "Cleaning up local kube config... "
kubectl config delete-context "${CLUSTER_NAME}-admin" 2>&1 >/dev/null
if [[ "$(kubectl config get-contexts -o name)" == *"${CLUSTER_NAME}"* ]]; then
    kubectl config delete-context "${CLUSTER_NAME}" 2>&1 >/dev/null
fi
kubectl config delete-cluster "${CLUSTER_NAME}" 2>&1 >/dev/null
echo "Done."

echo "Deleting vnet... "
az network vnet peering delete -g "$AZ_RESOURCE_GROUP_CLUSTERS" -n $VNET_PEERING_NAME --vnet-name $VNET_NAME
az network vnet peering delete -g "$AZ_RESOURCE_GROUP_VNET_HUB" -n $HUB_PEERING_NAME --vnet-name $AZ_VNET_HUB_NAME
az network vnet delete -g "$AZ_RESOURCE_GROUP_CLUSTERS" -n $VNET_NAME 2>&1 >/dev/null
echo "Done."

function removeLinkPrivateDnsZoneToVNET() {
    dns_zone=${1}
    DNS_ZONE_LINK_EXIST="$(az network private-dns link vnet show -g $AZ_RESOURCE_GROUP_VNET_HUB -n $VNET_DNS_LINK -z $dns_zone --query "type" --output tsv)"
    if [[ $DNS_ZONE_LINK_EXIST == "Microsoft.Network/privateDnsZones/virtualNetworkLinks" ]]; then
        echo "Removing link from private DNS Zone:  ${dns_zone} to K8S VNET ${VNET_ID}"
        az network private-dns link vnet delete -g $AZ_RESOURCE_GROUP_VNET_HUB -n $VNET_DNS_LINK -z $dns_zone -y
    fi
}

# linking private dns zones to vnet
echo "Removing link from private DNS Zones to vnet $VNET_NAME... "
for dns_zone in "${AZ_PRIVATE_DNS_ZONES[@]}"; do
    removeLinkPrivateDnsZoneToVNET $dns_zone &
done
wait

# TODO: Clean up velero blob dialog (yes/no)


#######################################################################################
### END
###

echo ""
echo "Teardown done!"

