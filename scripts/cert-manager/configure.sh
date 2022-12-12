#!/usr/bin/env bash


#######################################################################################
### PURPOSE
### 

# Apply cert-manager manifests and annotate secrets for Kubed sync

#######################################################################################
### PRECONDITIONS
### 

# - AKS cluster is available
# - User has role cluster-admin
# - Flux has been deployed to the cluster
# - Cert-manager has been deployed in the cluster

#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

# Optional:
# - STAGING             : Use cert issuer staging api? true/false. Default is false.
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
### 

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./configure.sh

# STAGING
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" STAGING=true ./configure.sh


#######################################################################################
### DOCS
###

# - https://cert-manager.io/docs/configuration/acme/dns01/azuredns/


#######################################################################################
### START
### 

echo ""
echo "Start applying cert-manager manifests and annotate secrets for Kubed sync... "

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for necessary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2;  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2;  exit 1; }
hash helm 2> /dev/null  || { echo -e "\nERROR: helm not found in PATH. Exiting..." >&2;  exit 1; }
hash jq 2> /dev/null  || { echo -e "\nERROR: jq not found in PATH. Exiting..." >&2;  exit 1; }
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

if [[ -z "$STAGING" ]]; then
    STAGING=false
fi

# Script vars

WORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ $STAGING == false ]]; then
    CERT_ISSUER="letsencrypt-prod"
    ACME_URL="https://acme-v02.api.letsencrypt.org/directory"
else
    CERT_ISSUER="letsencrypt-staging"
    ACME_URL="https://acme-staging-v02.api.letsencrypt.org/directory"
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
echo -e "Configuration of cert-manager will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e "   -  AZ_RESOURCE_DNS                  : $AZ_RESOURCE_DNS"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  CERT-MANAGER                     : v1.1"
echo -e "   -  CERT_ISSUER                      : $CERT_ISSUER"
echo -e "   -  ACME_URL                         : $ACME_URL"
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
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    echo ""
fi

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {    
    # Send message to stderr
    echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 1        
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
verify_cluster_access

#######################################################################################
### Verify cert-manager deployment
###

# https://cert-manager.io/docs/installation/verify/

# We already know that the pods are in a running state from the migration script, so here we create an issuer and issue a certificate
echo ""
echo "Verify cert-manager deployment..."

echo "Create test resources..."
cat <<EOF > test-resources.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-test
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: cert-manager-test
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: selfsigned-cert
  namespace: cert-manager-test
spec:
  dnsNames:
    - example.com
  secretName: selfsigned-cert-tls
  issuerRef:
    name: test-selfsigned
EOF

# Verify that the test resources can be deployed
kubectl create namespace cert-manager-test 2>&1 >/dev/null
while [[ "$(kubectl apply --dry-run=server -f test-resources.yaml 2>&1)" == *"error"* ]]; do
    printf "."
    sleep 1
done
kubectl delete namespace cert-manager-test 2>&1 >/dev/null

# Deploy the test resources
kubectl apply -f test-resources.yaml

# Wait for the certificate status to be True
printf "Validate test certificate...\n"
while [[ "$(kubectl get certificate -n cert-manager-test selfsigned-cert -ojson | jq -r '.status.conditions[0].status' 2>&1)" != "True" ]]; do
    printf "."
    sleep 1
done
printf "...Done.\n"

echo "Validation successful!"

echo "Remove test resources..."
kubectl delete -f test-resources.yaml
rm -f test-resources.yaml

#######################################################################################
### Transform and apply all custom resources
###

function createIdentityResourceAndBinding() {
    # Use managed identity
    printf "\nCreate identity resource and binding, and certificate issuer...\n"

    # Get the already created identity
    printf "Getting identity..."
    IDENTITY="$(az identity show --name $MI_CERT_MANAGER --resource-group $AZ_RESOURCE_GROUP_COMMON --output json 2>&1)"
    if [[ $IDENTITY == *"ERROR"* ]]; then
        echo "ERROR: Could not get identity." >&2
        exit 1
    fi
    printf " Done.\n"

    # Used for identity binding
    CLIENT_ID=$(echo $IDENTITY | jq -r '.clientId')
    RESOURCE_ID=$(echo $IDENTITY | jq -r '.id')

    # Combine and use the templated manifest as a heredocs.
    # First we paste it into a heredoc script file.
    # Then we will then run the heredoc script in context of caller using the "source" command so that it share scope with caller and have access the same vars.
    # The final output will be a yaml file which contains the translated manifest.
    local TMP_DIR="${WORK_DIR}/tmp"
    test -d "$TMP_DIR" && rm -rf "$TMP_DIR"
    mkdir "$TMP_DIR"
    (echo "#!/bin/sh"; echo "cat <<EOF >>${TMP_DIR}/translated-manifest.yaml"; cat $WORK_DIR/mi-azure-identity-and-issuer.yaml | cat; echo ""; echo "EOF";)>${TMP_DIR}/heredoc.sh && chmod +x ${TMP_DIR}/heredoc.sh
    source ${TMP_DIR}/heredoc.sh

    kubectl apply -f ${TMP_DIR}/translated-manifest.yaml
    rm -rf "${TMP_DIR}"
    printf "...Done.\n"
}

function transformManifests() {
    # Use Service Principal

    # Fetch dns system user credentials
    # Read secret, extract stringified json from property "value" and convert it into json
    local DNS_SP="$(az keyvault secret show \
        --vault-name $AZ_RESOURCE_KEYVAULT \
        --name $APP_REGISTRATION_CERT_MANAGER \
        | jq '.value | fromjson')"

    # Set variables used in the manifest templates
    local DNS_SP_ID="$(echo $DNS_SP | jq -r '.id')"
    local DNS_SP_TENANT_ID="$(echo $DNS_SP | jq -r '.tenantId')"
    local DNS_SP_PASSWORD="$(echo $DNS_SP | jq -r '.password')"
    local DNS_SP_PASSWORD_base64="$(echo $DNS_SP_PASSWORD | base64 -)"

    # Combine and use the templated manifests as a heredocs.
    # First we combine them all into one heredoc script file.
    # Then we will then run the heredoc script in context of caller using the "source" command so that it share scope with caller and have access the same vars.
    # The final output will be a yaml file that contains all the translated manifests.
    local TMP_DIR="${WORK_DIR}/tmp"
    test -d "$TMP_DIR" && rm -rf "$TMP_DIR"
    mkdir "$TMP_DIR"
    (echo "#!/bin/sh"; echo "cat <<EOF >>${TMP_DIR}/translated-manifests.yaml"; (for templateFile in "$WORK_DIR"/manifests/*.yaml; do cat $templateFile; done;) | cat; echo ""; echo "EOF";)>${TMP_DIR}/heredoc.sh && chmod +x ${TMP_DIR}/heredoc.sh
    source ${TMP_DIR}/heredoc.sh
    printf "...Done.\n"
}

function applyManifests() {
    # Use Service principal
    printf "\nStart applying manifests...\n"

    local TMP_DIR="${WORK_DIR}/tmp"
    kubectl apply -f "${TMP_DIR}/translated-manifests.yaml"
    rm -rf "${TMP_DIR}"

    # # Use managed identity
    # test -d "$TMP_DIR" && rm -rf "$TMP_DIR"
    # mkdir "$TMP_DIR"

    # (echo "#!/bin/sh";
    # echo "cat <<EOF >>${TMP_DIR}/translated-manifests.yaml";
    # cat $WORK_DIR/manifests/radix-wildcard-tls-cert.yaml | cat;
    # echo "";
    # echo "EOF";)>${TMP_DIR}/heredoc.sh && chmod +x ${TMP_DIR}/heredoc.sh

    # source ${TMP_DIR}/heredoc.sh

    # kubectl apply -f ${TMP_DIR}/translated-manifests.yaml
    # rm -rf "${TMP_DIR}"
    printf "...Done.\n"
}

#######################################################################################
### MAIN
###

# # Use managed identity
# createIdentityResourceAndBinding # Do not use this until aad-pod-identity is generally available.

# Use service principal
transformManifests

applyManifests
