#!/bin/bash

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

echo "Getting secrets from keyvault..."
DYNATRACE_API_URL=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-api-url | jq -r .value)
DYNATRACE_API_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-tenant-token | jq -r .value)
DYNATRACE_PAAS_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-paas-token | jq -r .value)
SKIP_CERT_CHECK="true"

# Store the secrets in a temporary .yaml file.
echo "apiUrl: ${DYNATRACE_API_URL}
apiToken: ${DYNATRACE_API_TOKEN}
paasToken: ${DYNATRACE_PAAS_TOKEN}
skipCertCheck: ${SKIP_CERT_CHECK}
networkZone: ${CLUSTER_NAME}
kubernetesMonitoring:
  enabled: true
  group: ${CLUSTER_NAME}
routing:
  enabled: true
  group: ${CLUSTER_NAME}
classicFullStack:
  enabled: true
  tolerations:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
    operator: Exists
  args:
  - --set-host-group=${CLUSTER_NAME}" > dynatrace-values.yaml

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

echo "Bootstrap of Dynatrace is complete."