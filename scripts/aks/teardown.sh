#!/bin/bash

# PURPOSE
#
# Teardown of a aks cluster and any related infrastructure (vnet and similar) or configuration that was created to specifically support that cluster.

# INPUTS:
#   AZ_INFRASTRUCTURE_ENVIRONMENT   (Mandatory - "prod" or "dev")
#   CLUSTER_NAME                    (Mandatory. Example: "prod43")

# USAGE
#
# AZ_INFRASTRUCTURE_ENVIRONMENT=dev CLUSTER_NAME=bad-hamster ./teardown.sh



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
### CONFIGS
###

### Validate mandatory input

if [[ -z "$AZ_INFRASTRUCTURE_ENVIRONMENT" ]]; then
    echo "Please provide AZ_INFRASTRUCTURE_ENVIRONMENT. Value must be one of: \"prod\", \"dev\"."
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME."
    exit 1
fi

### Get radix base env vars
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../${AZ_INFRASTRUCTURE_ENVIRONMENT}.env"
### Get cluster config that correnspond to selected environment
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/${AZ_INFRASTRUCTURE_ENVIRONMENT}.env"


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

echo ""
echo "Teardown will use the following configuration:"
echo ""
echo "   AZ_INFRASTRUCTURE_ENVIRONMENT: $AZ_INFRASTRUCTURE_ENVIRONMENT"
echo "   CLUSTER_NAME                 : $CLUSTER_NAME"
echo "   AZ_SUBSCRIPTION              : $AZ_SUBSCRIPTION"
echo "   AZ_USER                      : $(az account show --query user.name)"
echo ""

read -p "Is this correct? (Y/n) " -n 1 -r
if [[ "$REPLY" =~ (N|n) ]]; then
   echo ""
   echo "Quitting."
   exit 1
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
az network vnet delete -g "$AZ_RESOURCE_GROUP_CLUSTERS" -n $VNET_NAME 2>&1 >/dev/null
echo "Done."

# TODO: Clean up velero blob dialog (yes/no)


#######################################################################################
### END
###

echo ""
echo "Teardown done!"

