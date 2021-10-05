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

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=beastmode-11 ./teardown.sh



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
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/${CLUSTER_TYPE}.env"

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
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
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
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
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
### Delete replyUrls
###

function deleteReplyUrl() {
    aadAppName=$1
    aadAppId=$2
    replyUrl=$3
    # Get the index number of the replyUrl we want to delete
    readarray -t array < <(az ad app show --id ${aadAppId} --query replyUrls --output json | jq -r '.[]')
    for i in "${!array[@]}"; do
        if [[ "${array[$i]}" = "${replyUrl}" ]]; then
            index="${i}"
        fi
    done

    if [[ -z $index ]]; then
        echo "ReplyUrl \"${replyUrl}\" not found in App Registration \"${aadAppName}\"."
    else
        echo ""
        printf "Deleting replyUrl \"${replyUrl}\" from App Registration \"${aadAppName}\"..."
        az ad app update --id "${aadAppId}" --remove replyUrls ${index}
        printf " Done.\n"
    fi
}

# Delete replyUrl for Radix web-console
APP_REGISTRATION_WEB_CONSOLE="Omnia Radix Web Console - ${CLUSTER_TYPE^} Clusters" # "Development", "Playground", "Production"
aadAppId="$(az ad app list --display-name "${APP_REGISTRATION_WEB_CONSOLE}" --query [].appId -o tsv)"
if [[ $CLUSTER_TYPE  == "development" ]]; then
    K8S_NAMESPACE="radix-web-console-qa"
else
    K8S_NAMESPACE="radix-web-console-prod"
fi
host_name=$(kubectl get ing -n ${K8S_NAMESPACE} auth -o json | jq --raw-output .spec.rules[0].host)
replyUrl="https://${host_name}/oauth2/callback"

deleteReplyUrl $APP_REGISTRATION_WEB_CONSOLE $aadAppId $replyUrl

# Delete replyUrl for grafana
aadAppId="$(az ad app list --display-name "${APP_REGISTRATION_GRAFANA}" --query [].appId -o tsv)"
host_name=$(kubectl get ing -n grafana -o json | jq --raw-output .spec.rules[0].host)
replyUrl="https://${host_name}/login/generic_oauth"

deleteReplyUrl $APP_REGISTRATION_GRAFANA $aadAppId $replyUrl

#######################################################################################
### Delete related stuff
###

echo "Deleting Dynatrace integration..."
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" USER_PROMPT="false" CLUSTER_NAME="$CLUSTER_NAME" ../dynatrace/teardown.sh)

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

# TODO: Clean up velero blob dialog (yes/no)

echo ""
echo "Delete DNS records"
(RADIX_ENVIRONMENT="$RADIX_ENVIRONMENT" CLUSTER_TYPE="$CLUSTER_TYPE" RESOURCE_GROUP="$RESOURCE_GROUP" DNS_ZONE="$DNS_ZONE" CLUSTER_NAME="$CLUSTER_NAME" ../dns/delete_dns_entries_for_cluster.sh)
wait # wait for subshell to finish

echo ""
echo "Delete orphaned DNS records"
(RADIX_ENVIRONMENT="$RADIX_ENVIRONMENT" CLUSTER_TYPE="$CLUSTER_TYPE" RESOURCE_GROUP="$RESOURCE_GROUP" DNS_ZONE="$DNS_ZONE" ../dns/delete_dns_entries.sh)
wait # wait for subshell to finish

#######################################################################################
### END
###

echo ""
echo "Teardown done!"

