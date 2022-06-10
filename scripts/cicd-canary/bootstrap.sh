#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap radix-cicd-canary in a radix cluster

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin
# - Helm RBAC is configured in cluster
# - Secret "radix-cicd-canary-values" is available in the keyvault

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./bootstrap.sh

#######################################################################################
### START
###
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

echo ""
echo "Start bootstrap of radix-cicd-canary... "

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

script_dir_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Optional inputs

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "\nConnecting kubectl..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS"  --name "$CLUSTER_NAME" 2>&1)"" == *"ERROR"* ]]; then    
    # Send message to stderr
    echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 0        
fi
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
printf "Verifying cluster access..."
if [[ $(kubectl cluster-info 2>&1) == *"Unable to connect to the server"* ]]; then
    printf "ERROR: Could not access cluster. Quitting...\n" >&2
    exit 1
fi
printf " OK\n"

echo "Install Radix CICD Canary"
SECRET_VALUES=$(az keyvault secret show \
    --vault-name "$AZ_RESOURCE_KEYVAULT" \
    --name radix-cicd-canary-values |
    jq '.value | fromjson')

# Create .yaml with values from keyvault.
YAML_SECRET_FILE="radix-cicd-canary-values.yaml"
echo "impersonate:
  user: $(echo $SECRET_VALUES | jq -r '.impersonate.user')

deployKey:
  public: $(echo $SECRET_VALUES | jq -r '.deployKey.public')
  private: $(echo $SECRET_VALUES | jq -r '.deployKey.private')

deployKeyCanary3:
  public: $(echo $SECRET_VALUES | jq -r '.deployKeyCanary3.public')
  private: $(echo $SECRET_VALUES | jq -r '.deployKeyCanary3.private')

deployKeyCanary4:
  public: $(echo $SECRET_VALUES | jq -r '.deployKeyCanary4.public')
  private: $(echo $SECRET_VALUES | jq -r '.deployKeyCanary4.private')

privateImageHub:
  password: $(echo $SECRET_VALUES | jq -r '.privateImageHub.password')

networkPolicyCanary:
  password: $(echo $SECRET_VALUES | jq -r '.networkPolicyCanary.password')

clusterType: $CLUSTER_TYPE
clusterFqdn: $CLUSTER_NAME.$AZ_RESOURCE_DNS
" >> $YAML_SECRET_FILE

# Create radix-cicd-canary namespace
kubectl create ns radix-cicd-canary --dry-run=client --save-config -o yaml |
    kubectl apply -f -

# Create secret 
kubectl create secret generic canary-secrets --namespace radix-cicd-canary \
    --from-file=./$YAML_SECRET_FILE \
    --dry-run=client -o yaml |
    kubectl apply -f -

rm -f $YAML_SECRET_FILE

echo "Updating radix-networkpolicy-canary HTTP password..."
printf "%s► Execute %s%s\n" "${grn}" "${script_dir_path}/update_secret_for_networkpolicy_canary.sh" "${normal}"
(RADIX_ZONE_ENV=${RADIX_ZONE_ENV} CLUSTER_NAME=${CLUSTER_NAME} ${script_dir_path}/update_secret_for_networkpolicy_canary.sh)

echo "Done."
