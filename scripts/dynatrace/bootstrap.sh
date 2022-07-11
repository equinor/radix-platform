#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap dynatrace in a radix cluster
# This script will: 
# - create the dynatrace namespace
# - retrieve the dynatrace secrets from the keyvault
# - store the secrets in a kubernetes secret

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin
# - Helm RBAC is configured in cluster
# - Following secrets in keyvault:
#       - dynatrace-api-url
#       - dynatrace-tenant-token (an API-token with config write permission)
#       - dynatrace-paas-token

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

echo ""
echo "Start bootstrap of dynatrace... "

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
else
    # Set cluster name variable for dynatrace integration
    INITIAL_CLUSTER_NAME=$CLUSTER_NAME
    CLUSTER_NAME="radix-$CLUSTER_TYPE-$INITIAL_CLUSTER_NAME"
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

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
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$INITIAL_CLUSTER_NAME" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"$INITIAL_CLUSTER_NAME\" not found." >&2
    exit 1        
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
verify_cluster_access

echo "Getting secrets from keyvault..."
DYNATRACE_API_URL=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-api-url | jq -r .value)
DYNATRACE_API_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-tenant-token | jq -r .value)
DYNATRACE_PAAS_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-paas-token | jq -r .value)
SKIP_CERT_CHECK="true"

# Store the secrets in a temporary .yaml file.
echo "platform: kubernetes
apiUrl: ${DYNATRACE_API_URL}
apiToken: ${DYNATRACE_API_TOKEN}
paasToken: ${DYNATRACE_PAAS_TOKEN}
skipCertCheck: ${SKIP_CERT_CHECK}
networkZone: ${CLUSTER_NAME}
classicFullStack:
  enabled: true
  tolerations:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
    operator: Exists
  args:
  - --set-host-group=${CLUSTER_NAME}
activeGate:
  capabilities:
  - kubernetes-monitoring
  group: ${CLUSTER_NAME}" > dynatrace-values.yaml

# Create the dynatrace namespace.
echo "Creating Dynatrace namespace..."
if ! kubectl get ns dynatrace >/dev/null 2>&1; then
  kubectl create namespace dynatrace
fi

# Create the secret to be used in the helm chart for deploying Dynatrace.
echo "Creating dynatrace-secret..."
kubectl create secret generic dynatrace-secret --namespace dynatrace \
    --from-file=./dynatrace-values.yaml \
    --dry-run=client -o yaml |
    kubectl apply -f -

# Delete the temporary .yaml file.
rm -f dynatrace-values.yaml

# Add Dynatrace operator CRD https://github.com/Dynatrace/dynatrace-operator/releases 
kubectl apply -f https://github.com/Dynatrace/dynatrace-operator/releases/download/v0.4.2/dynatrace.com_dynakubes.yaml

# Change variable back to initial value
CLUSTER_NAME=$INITIAL_CLUSTER_NAME

echo "Bootstrap of Dynatrace is complete."
