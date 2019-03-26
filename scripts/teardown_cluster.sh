#!/bin/bash

# PURPOSE
#
# Teardown of a aks cluster and any related infrastructure (vnet and similar) or configuration that was created to specifically support that cluster.

# INPUTS:
#   INFRASTRUCTURE_ENVIRONMENT  (Mandatory - "prod" or "dev")
#   CLUSTER_NAME                (Mandatory. Example: "prod43")
#
# To run this script from terminal:
# INFRASTRUCTURE_ENVIRONMENT=dev CLUSTER_NAME=mah-bestest-cluster ./teardown_cluster.sh

#######################################################################################
### Validate mandatory input
###

if [[ -z "$INFRASTRUCTURE_ENVIRONMENT" ]]; then
    echo "Please provide INFRASTRUCTURE_ENVIRONMENT. Value must be one of: \"prod\", \"dev\"."
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME."
    exit 1
fi

#######################################################################################
### Set default values
###

AZ_SUBSCRIPTION_DEV="Omnia Radix Development"
AZ_SUBSCRIPTION_PROD="Omnia Radix Production"
AZ_SUBSCRIPTION_SELECTED=""

case "$INFRASTRUCTURE_ENVIRONMENT" in
    "dev" )
        AZ_SUBSCRIPTION_SELECTED="$AZ_SUBSCRIPTION_DEV"
        ;;

    "prod" )
        AZ_SUBSCRIPTION_SELECTED="$AZ_SUBSCRIPTION_PROD"
        ;;

    *)
        # Exit for anything else
        echo "Please provide INFRASTRUCTURE_ENVIRONMENT. Value must be one of: \"prod\", \"dev\"."
        exit 1
        ;;
esac

VNET_NAME="vnet-$CLUSTER_NAME"
RESOURCE_GROUP="clusters"

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting...";  exit 1; }
printf "Ok."
echo ""


#######################################################################################
### Login to Azure if not already logged inn
###

echo ""
echo "Logging you in to Azure if not already logged in"
az account show > /dev/null || az login > /dev/null
az account set --subscription "$AZ_SUBSCRIPTION_SELECTED" > /dev/null

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Start teardown of cluster using the following settings:"
echo -e ""
echo -e "SUBSCRIPTION_ENVIRONMENT: $INFRASTRUCTURE_ENVIRONMENT"
echo -e "CLUSTER_NAME            : $CLUSTER_NAME"
echo -e "AZ_SUBSCRIPTION         : $AZ_SUBSCRIPTION_SELECTED"
echo -e "AZ_USER                 : $(az account show --query user.name)"
echo -e ""

read -p "Is this correct? (Y/n) " -n 1 -r
if [[ "$REPLY" =~ (N|n) ]]; then
   echo ""
   echo "Quitting."
   exit 1
fi

#######################################################################################
### TODO: delete replyUrls
###

# Use ingress host name to filter AAD app replyUrl list.

#######################################################################################
### Delete cluster
###

echo ""
echo "Deleting cluster..."
az aks delete --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --yes


#######################################################################################
### Delete related stuff
###

echo ""
echo "Deleting vnet..."
az network vnet delete -g "$RESOURCE_GROUP" -n $VNET_NAME


#######################################################################################
### End
###

echo ""
echo "Teardown done!"

