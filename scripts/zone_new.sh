#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Create new cluster in new zone with some resources from 

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE              : Ex: 'd1'
# - DEST_CLUSTER            : Ex: 'disaster-22'
# - AZ_SUBSCRIPTION_NAME    : Ex: s612

#######################################################################################
### HOW TO USE
###
# RADIX_ZONE=d1 DEST_CLUSTER=disaster-22 AZ_SUBSCRIPTION_NAME=s612 ./zone_new.sh

if [[ -z "$RADIX_ZONE" ]]; then
    echo "ERROR: Please provide RADIX_ZONE" >&2
    exit 1
fi

if [[ -z "$DEST_CLUSTER" ]]; then
    echo "ERROR: Please provide DEST_CLUSTER" >&2
    exit 1
fi

if [[ -z "$AZ_SUBSCRIPTION_NAME" ]]; then
    echo "ERROR: Please provide AZ_SUBSCRIPTION_NAME" >&2
    exit 1
fi

RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)
printf "Checkout follwing tasks to populate new zone:\n"
printf "%s◄ Populate following terraform folder: %s%s\n" "${yel}" "$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE from template in $RADIX_PLATFORM_REPOSITORY_PATH/terraform/templates/zone_new" "${normal}"
printf "%s► Execute: %s%s\n" "${yel}" "terraform -chdir=$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters init" "${normal}"
printf "%s► Execute: %s%s\n" "${yel}" "terraform -chdir=$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters apply" "${normal}"
printf "%s► Populate Keyvault %s%s\n" "${yel}" "radix-keyv-$RADIX_ZONE with items found in the readme.md ($RADIX_PLATFORM_REPOSITORY_PATH/terraform/templates/zone_new/README.md)" "${normal}"

REQ_FLUX_VERSION="2.5.1"
FLUX_VERSION=$(flux --version | awk '{print $3'})
if [[ "$FLUX_VERSION" != "${REQ_FLUX_VERSION}" ]]; then
    printf ""${yel}"Please update flux cli to ${REQ_FLUX_VERSION}. You got version $FLUX_VERSION${normal}\n"
    exit 1
fi

RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh
RADIX_ZONE="d1"
printf "\n%s► Read YAML configfile $RADIX_ZONE"
RADIX_ZONE_ENV=$(config_path $RADIX_ZONE)
printf "\n%s► Read terraform variables and configuration"
RADIX_RESOURCE_JSON=$(environment_json $RADIX_ZONE)
RADIX_ZONE_YAML=$(cat <<EOF
$(<$RADIX_ZONE_ENV)
EOF
)

AZ_RADIX_ZONE_LOCATION=$(yq '.location' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_DNS=$(jq -r .dnz_zone <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_KEYVAULT=$(jq -r .keyvault <<< "$RADIX_RESOURCE_JSON")
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
AZ_SUBSCRIPTION_NAME=$(yq '.subscription_shortname' <<< "$RADIX_ZONE_YAML")
CLUSTER_NAME="$DEST_CLUSTER"
IMAGE_REGISTRY=$(jq -r .acr <<< "$RADIX_RESOURCE_JSON")
MIGRATION_STRATEGY="aa"
RADIX_ENVIRONMENT=$(yq '.radix_environment' <<< "$RADIX_ZONE_YAML")
STORAGACCOUNT=$(jq -r .velero_sa <<< "$RADIX_RESOURCE_JSON")



echo ""
SELECTED_INGRESS_IP_RAW_ADDRESS=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" output -json clusters | jq -r '.[] | select(.cluster=="'${DEST_CLUSTER}'") | .ingressIp')
echo "IP: $SELECTED_INGRESS_IP_RAW_ADDRESS"
kubectl create namespace ingress-nginx --dry-run=client -o yaml |
kubectl apply -f -

kubectl create secret generic ingress-nginx-raw-ip \
    --namespace ingress-nginx \
    --from-literal=rawIp="$SELECTED_INGRESS_IP_RAW_ADDRESS" \
    --dry-run=client -o yaml |
    kubectl apply -f -

echo "controller:
service:
    loadBalancerIP: $SELECTED_INGRESS_IP_RAW_ADDRESS" > config

kubectl create secret generic ingress-nginx-ip \
    --namespace ingress-nginx \
    --from-file=./config \
    --dry-run=client -o yaml |
    kubectl apply -f -

rm config
printf "Done.\n"



#######################################################################################
### Install Flux
echo ""
echo "Install Flux v2"
echo ""
FLUX_PRIVATE_KEY_NAME="flux-github-deploy-key-private"
FLUX_PRIVATE_KEY="$(az keyvault secret show --name "$FLUX_PRIVATE_KEY_NAME" --vault-name "$AZ_RESOURCE_KEYVAULT")"

echo "Creating \"radix-flux-config\"..."

# list of public ips assigned to the cluster
printf "\nGetting list of public ips assigned to $CLUSTER_NAME..."
ASSIGNED_IPS="$(az network public-ip list \
    --query "[?ipConfiguration.resourceGroup=='MC_${AZ_RESOURCE_GROUP_CLUSTERS}_${CLUSTER_NAME}_${AZ_RADIX_ZONE_LOCATION}'].ipAddress" \
    --output json)"

if [[ "$ASSIGNED_IPS" == "[]" ]]; then
    echo "ERROR: Could not find Public IP of cluster." >&2
else
    # Loop through list of IPs and create a comma separated string.
    for ipaddress in $(echo $ASSIGNED_IPS | jq -cr '.[]'); do
        if [[ -z $IP_LIST ]]; then
            IP_LIST=$(echo $ipaddress)
        else
            IP_LIST="$IP_LIST,$(echo $ipaddress)"
        fi
    done
    printf "...Done\n"
fi
printf "\nGetting Slack Webhook URL..."
SLACK_WEBHOOK_URL="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name slack-webhook | jq -r .value)"
printf "...Done\n"

printf "\nWorking on namespace flux-system"
if [[ $(kubectl get namespace flux-system 2>&1) == *"Error"* ]]; then
    kubectl create ns flux-system 2>&1 >/dev/null
fi
printf "...Done"
# Create configmap for Flux v2 to use for variable substitution. (https://fluxcd.io/docs/components/kustomize/kustomization/#variable-substitution)
printf "Deploy \"radix-flux-config\" configmap in flux-system namespace..."
kubectl create configmap radix-flux-config -n flux-system \
    --from-literal=dnsZone="$AZ_RESOURCE_DNS" \
    --from-literal=appAliasBaseURL="app.$AZ_RESOURCE_DNS" \
    --from-literal=prometheusName="radix-stage1" \
    --from-literal=imageRegistry="$IMAGE_REGISTRY" \
    --from-literal=clusterName="$CLUSTER_NAME" \
    --from-literal=clusterType="$(yq '.cluster_type' <<< "$RADIX_ZONE_YAML")" \
    --from-literal=activeClusterIPs="$IP_LIST" \
    --from-literal=slackWebhookURL="$SLACK_WEBHOOK_URL"
printf "...Done.\n"

az keyvault secret download \
--vault-name "$AZ_RESOURCE_KEYVAULT" \
--name "$FLUX_PRIVATE_KEY_NAME" \
--file "$FLUX_PRIVATE_KEY_NAME" 2>&1 >/dev/null

echo "Installing flux with your flux version: v$FLUX_VERSION"
flux bootstrap git \
--private-key-file="$FLUX_PRIVATE_KEY_NAME" \
--url="ssh://git@github.com/equinor/radix-flux" \
--branch="master" \
--path="clusters/$(yq '.flux_folder' <<< "$RADIX_ZONE_YAML")" \
--components-extra=image-reflector-controller,image-automation-controller \
--version="v$FLUX_VERSION" \
--silent
if [[ "$?" != "0" ]]; then
    printf "\nERROR: flux bootstrap git failed. Exiting...\n" >&2
    rm "$FLUX_PRIVATE_KEY_NAME"
    exit 1
else
    rm "$FLUX_PRIVATE_KEY_NAME"
    echo " Done."
fi

echo -e ""
echo -e "A Flux service has been provisioned in the cluster to follow the GitOps way of thinking."