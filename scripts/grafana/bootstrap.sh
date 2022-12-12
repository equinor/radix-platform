#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap grafana in a radix cluster

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin
# - grafana-database-password exists in keyvault

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "playground-2", "weekly-93"

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./bootstrap.sh

#######################################################################################
### START
###

echo ""

# Load dependencies
LIB_SERVICE_PRINCIPAL_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../service-principals-and-aad-apps/lib_service_principal.sh"
if [[ ! -f "$LIB_SERVICE_PRINCIPAL_PATH" ]]; then
    echo "ERROR: The dependency LIB_SERVICE_PRINCIPAL_PATH=$LIB_SERVICE_PRINCIPAL_PATH is invalid, the file does not exist." >&2
    exit 1
else
    source "$LIB_SERVICE_PRINCIPAL_PATH"
fi

# Script vars
WORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo ""
echo "Start bootstrap of Grafana... "

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2
    exit 1
}
hash helm 2>/dev/null || {
    echo -e "\nERROR: helm not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}
printf "All is good."
echo ""

#######################################################################################
### Read inputs and configs
###

# Required inputs

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

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

# Optional inputs

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
echo -e "Install Grafana will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  APP_REGISTRATION_GRAFANA         : $APP_REGISTRATION_GRAFANA"
echo -e "   -  AZ_RESOURCE_DNS                  : $AZ_RESOURCE_DNS"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Is this correct? (Y/n) " yn
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

#######################################################################################
### CLUSTER?
###

kubectl_context="$(kubectl config current-context)"

if [ "$kubectl_context" = "$CLUSTER_NAME" ] || [ "$kubectl_context" = "${CLUSTER_NAME}" ]; then
    echo "kubectl is ready..."
else
    echo "ERROR: Please set your kubectl current-context to be ${CLUSTER_NAME}" >&2
    exit 1
fi

#######################################################################################
### Verify cluster access
###
verify_cluster_access

#######################################################################################
### Create secret required by Grafana
###

echo "Install secret grafana-secret in cluster"

GF_CLIENT_ID="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $APP_REGISTRATION_GRAFANA | jq -r .value | jq -r .id)"
GF_CLIENT_SECRET="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $APP_REGISTRATION_GRAFANA | jq -r .value | jq -r .password)"
GF_DB_PWD="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name grafana-database-password | jq -r .value)"

# Transform clustername to lowercase
CLUSTER_NAME_LOWER="$(echo "$CLUSTER_NAME" | awk '{print tolower($0)}')"

# Before moving custom ingresses, the root url should be cluster-specific.
GF_SERVER_ROOT_URL="https://grafana.$CLUSTER_NAME_LOWER.$AZ_RESOURCE_DNS"

echo "ingress:
  enabled: true
  hosts:
  - grafana.$CLUSTER_NAME_LOWER.$AZ_RESOURCE_DNS
  tls:
  - secretName: radix-wildcard-tls-cert
    hosts:
    - grafana.$CLUSTER_NAME_LOWER.$AZ_RESOURCE_DNS
env:
  GF_SERVER_ROOT_URL: $GF_SERVER_ROOT_URL" > config

kubectl create secret generic grafana-helm-secret \
    --from-file=./config \
    --dry-run=client -o yaml |
    kubectl apply -f -

rm -f config

kubectl create secret generic grafana-secrets \
    --from-literal=GF_AUTH_GENERIC_OAUTH_CLIENT_ID=$GF_CLIENT_ID \
    --from-literal=GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=$GF_CLIENT_SECRET \
    --from-literal=GF_DATABASE_PASSWORD=$GF_DB_PWD \
    --dry-run=client \
    -o yaml |
    kubectl apply -f -

# #######################################################################################
# ### Install Grafana
# ###
# helm repo add grafana https://grafana.github.io/helm-charts
# helm repo update
# helm upgrade --install grafana grafana/grafana -f "${WORK_DIR}/grafana-values.yaml" \
#   --version v6.12.0 \
#   --set ingress.hosts[0]=grafana."$CLUSTER_NAME_LOWER.$AZ_RESOURCE_DNS" \
#   --set ingress.tls[0].hosts[0]=grafana."$CLUSTER_NAME_LOWER.$AZ_RESOURCE_DNS" \
#   --set ingress.tls[0].secretName=radix-wildcard-tls-cert \
#   --set env.GF_SERVER_ROOT_URL=$GF_SERVER_ROOT_URL

printf "Done.\n"
