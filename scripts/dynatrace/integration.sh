#!/bin/bash

#######################################################################################
### PURPOSE
###

# After base components have been installed and Dynatrace has been deployed, connect the cluster to Dynatrace by updating the
# kubernetes credentials using the Dynatrace API.

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin
# - Dynatrace has been deployed

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
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./integration.sh

#######################################################################################
### START
###

echo ""
while true; do
  read -p "Is this correct? (Y/n) " yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) echo ""; echo "Quitting."; exit 0;;
    * ) echo "Please answer yes or no.";;
  esac
done

echo ""
echo "Start update of Kubernetes credentials in Dynatrace..."

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
else
    # Set cluster name variable for dynatrace integration
    INITIAL_CLUSTER_NAME=$CLUSTER_NAME
    CLUSTER_NAME="radix-$CLUSTER_TYPE-$INITIAL_CLUSTER_NAME"
fi

# Get secrets: api-url and tenant-token from keyvault
API_URL=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-api-url | jq -r .value)
API_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-tenant-token | jq -r .value)

# Logic imported from install.sh in https://github.com/Dynatrace/dynatrace-operator/releases/tag/v0.2.2

set -e

CLI="kubectl"
SKIP_CERT_CHECK="true"
CLUSTER_NAME_LENGTH=256
ENABLE_PROMETHEUS_INTEGRATION="true"

if [ -z "$API_URL" ]; then
  echo "Error: api-url not set!"
  exit 1
fi

if [ -z "$API_TOKEN" ]; then
  echo "Error: api-token not set!"
  exit 1
fi

K8S_ENDPOINT="$("${CLI}" config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
if [ -z "$K8S_ENDPOINT" ]; then
  echo "Error: failed to get kubernetes endpoint!"
  exit 1
fi

if [ -n "$CLUSTER_NAME" ]; then
  if ! echo "$CLUSTER_NAME" | grep -Eq "$CLUSTER_NAME_REGEX"; then
    echo "Error: cluster name \"$CLUSTER_NAME\" does not match regex: \"$CLUSTER_NAME_REGEX\""
    exit 1
  fi

  if [ "${#CLUSTER_NAME}" -ge $CLUSTER_NAME_LENGTH ]; then
    echo "Error: cluster name too long: ${#CLUSTER_NAME} >= $CLUSTER_NAME_LENGTH"
    exit 1
  fi
  CONNECTION_NAME="$CLUSTER_NAME"
else
  CONNECTION_NAME="$(echo "${K8S_ENDPOINT}" | awk -F[/:] '{print $4}')"
fi

set -u

addK8sConfiguration() {

  K8S_SECRET_NAME="$(for token in $("${CLI}" get sa dynatrace-kubernetes-monitoring -o jsonpath='{.secrets[*].name}' -n dynatrace); do echo "$token"; done | grep -F token)"
  if [ -z "$K8S_SECRET_NAME" ]; then
    echo "Error: failed to get kubernetes-monitoring secret!"
    exit 1
  fi

  K8S_BEARER="$("${CLI}" get secret "${K8S_SECRET_NAME}" -o jsonpath='{.data.token}' -n dynatrace | base64 --decode)"
  if [ -z "$K8S_BEARER" ]; then
    echo "Error: failed to get bearer token!"
    exit 1
  fi

  if "$SKIP_CERT_CHECK" = "true"; then
    CERT_CHECK_API="false"
  else
    CERT_CHECK_API="true"
  fi

  json="$(
    cat <<EOF
{
  "label": "${CLUSTER_NAME}",
  "endpointUrl": "${K8S_ENDPOINT}",
  "eventsFieldSelectors": [
    {
      "label": "Node events",
      "fieldSelector": "involvedObject.kind=Node",
      "active": true
    }
  ],
  "workloadIntegrationEnabled": true,
  "eventsIntegrationEnabled": false,
  "activeGateGroup": "${CLUSTER_NAME}",
  "authToken": "${K8S_BEARER}",
  "active": true,
  "certificateCheckEnabled": "${CERT_CHECK_API}",
  "prometheusExportersIntegrationEnabled": "${ENABLE_PROMETHEUS_INTEGRATION}"
}
EOF
  )"

  response=$(apiRequest "POST" "/config/v1/kubernetes/credentials" "${json}")

  if echo "$response" | grep -Fq "${CONNECTION_NAME}"; then
    echo "Kubernetes monitoring successfully setup."
  else
    echo "Error adding Kubernetes cluster to Dynatrace: $response"
  fi
}

checkForExistingCluster() {
  response=$(apiRequest "GET" "/config/v1/kubernetes/credentials" "")

  if echo "$response" | grep -Fq "\"name\":\"${CONNECTION_NAME}\""; then
    echo "Error: Cluster already exists: ${CONNECTION_NAME}"
    exit 1
  fi
}

checkTokenScopes() {
  jsonAPI="{\"token\": \"${API_TOKEN}\"}"

  responseAPI=$(apiRequest "POST" "/v1/tokens/lookup" "${jsonAPI}")

  if echo "$responseAPI" | grep -Fq "Authentication failed"; then
    echo "Error: API token authentication failed!"
    exit 1
  fi

  if ! echo "$responseAPI" | grep -Fq "WriteConfig"; then
    echo "Error: API token does not have config write permission!"
    exit 1
  fi

  if ! echo "$responseAPI" | grep -Fq "ReadConfig"; then
    echo "Error: API token does not have config read permission!"
    exit 1
  fi
}

apiRequest() {
  method=$1
  url=$2
  json=$3

  if "$SKIP_CERT_CHECK" = "true"; then
    curl_command="curl -k"
  else
    curl_command="curl"
  fi

  response="$(${curl_command} -sS -X ${method} "${API_URL}${url}" \
    -H "accept: application/json; charset=utf-8" \
    -H "Authorization: Api-Token ${API_TOKEN}" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "${json}")"

  echo "$response"
}

####### MAIN #######
printf "\nCheck for token scopes...\n"
checkTokenScopes
printf "\nCheck if cluster already exists...\n"
checkForExistingCluster
printf "\nAdding cluster to Dynatrace...\n"
addK8sConfiguration

# Change variable back to initial value
CLUSTER_NAME=$INITIAL_CLUSTER_NAME