#!/bin/bash

#!/bin/bash

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
    echo -e "\nError: Azure-CLI not found in PATH. Exiting..."
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nError: kubectl not found in PATH. Exiting..."
    exit 1
}
hash helm 2>/dev/null || {
    echo -e "\nError: helm not found in PATH. Exiting..."
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nError: jq not found in PATH. Exiting..."
    exit 1
}
printf "All is good."
echo ""

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
echo -e "   -  AZ_RESOURCE_AAD_SERVER           : $AZ_RESOURCE_AAD_SERVER"
echo -e "   -  AZ_RESOURCE_DNS                  : $AZ_RESOURCE_DNS"
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

echo ""

#######################################################################################
### CLUSTER?
###

kubectl_context="$(kubectl config current-context)"

if [ "$kubectl_context" = "$CLUSTER_NAME" ] || [ "$kubectl_context" = "${CLUSTER_NAME}-admin" ]; then
    echo "kubectl is ready..."
else
    echo "Please set your kubectl current-context to be ${CLUSTER_NAME}-admin"
    exit 1
fi

#######################################################################################
### Create secret required by Grafana
###

echo "Install secret grafana-secret in cluster"

GD_CLIENT_ID="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $AZ_RESOURCE_AAD_SERVER | jq -r .value | jq -r .id)"
GF_CLIENT_SECRET="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name $AZ_RESOURCE_AAD_SERVER | jq -r .value | jq -r .password)"
GF_DB_PWD="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name grafana-database-password | jq -r .value)"

kubectl create secret generic grafana-secrets \
    --from-literal=GF_AUTH_GENERIC_OAUTH_CLIENT_ID=$GD_CLIENT_ID \
    --from-literal=GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET=$GF_CLIENT_SECRET \
    --from-literal=GF_DATABASE_PASSWORD=$GF_DB_PWD \
    --dry-run=client \
    -o yaml |
    kubectl apply -f -

#######################################################################################
### Install Grafana
###
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm upgrade --install grafana grafana/grafana -f "${WORK_DIR}/grafana-values.yaml" \
  --version v6.2.0 \
  --set ingress.hosts[0]=grafana."$CLUSTER_NAME.$AZ_RESOURCE_DNS" \
  --set ingress.tls[0].hosts[0]=grafana."$CLUSTER_NAME.$AZ_RESOURCE_DNS" \
  --set ingress.tls[0].secretName=cluster-wildcard-tls-cert \
  --set env.GF_SERVER_ROOT_URL=https://grafana."$AZ_RESOURCE_DNS"

echo "Done."