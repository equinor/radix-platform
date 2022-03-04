#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Bootstrap prerequisites for external-dns (flux handles the main installation)

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./bootstrap.sh

#######################################################################################
### START
###

echo ""
echo "Start prerequisites for external-dns..."

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

# Configs and dependencies
CREDENTIALS_GENERATED_PATH="$(mktemp)"
CREDENTIALS_TEMPLATE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/template-azure.json"
if [[ ! -f "$CREDENTIALS_TEMPLATE_PATH" ]]; then
   echo "The dependency CREDENTIALS_TEMPLATE_PATH=$CREDENTIALS_TEMPLATE_PATH is invalid, the file does not exist." >&2
   exit 1
fi

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
    echo -e "Error: Cluster \"$CLUSTER_NAME\" not found." >&2
    exit 1        
fi
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
printf "Verifying cluster access..."
if [[ $(kubectl cluster-info 2>&1) == *"Unable to connect to the server"* ]]; then
    printf "ERROR: Could not access cluster. Quitting...\n"
    exit 1
fi
printf " OK\n"

#######################################################################################
### MAIN
###

# 1. Download secret in shell var
# 2. Create tmp azure.json using template
# 3. Create k8s secret with azure.json as payload
# 4. Ensure that generated credentials file is deleted on local machine even if script crash

function cleanup() {
    rm -f "$CREDENTIALS_GENERATED_PATH"
}

function generateCredentialsFile() {
    local DNS_SP="$(az keyvault secret show \
        --vault-name $AZ_RESOURCE_KEYVAULT \
        --name $AZ_SYSTEM_USER_DNS \
        | jq '.value | fromjson')"

    # Set variables used in the manifest templates
    local SP_DNS_ID="$(echo $DNS_SP | jq -r '.id')"
    local SP_DNS_TENANT_ID="$(echo $DNS_SP | jq -r '.tenantId')"
    local SP_DNS_PASSWORD="$(echo $DNS_SP | jq -r '.password')"
    #local SP_DNS_PASSWORD_base64="$(echo $SP_DNS_PASSWORD | base64 -)"

    # Use the credentials template as a heredoc, then run the heredoc to generate the credentials file
    CREDENTIALS_GENERATED_PATH="$(mktemp)"
    local tmp_heredoc="$(mktemp)"
    (echo "#!/bin/sh"; echo "cat <<EOF >>${CREDENTIALS_GENERATED_PATH}"; cat ${CREDENTIALS_TEMPLATE_PATH}; echo ""; echo "EOF";)>${tmp_heredoc} && chmod +x ${tmp_heredoc}
    source "$tmp_heredoc"

    # Debug
    # echo -e "\nCREDENTIALS_GENERATED_PATH=$CREDENTIALS_GENERATED_PATH"
    # echo -e "tmp_heredoc=$tmp_heredoc"

    # Remove even if script crashed
    #trap "rm -f $CREDENTIALS_GENERATED_PATH" 0 2 3 15
}

# Run cleanup even if script crashed
trap cleanup 0 2 3 15

generateCredentialsFile
kubectl create secret generic "external-dns-azure-secret" \
   --from-file="azure.json"="$CREDENTIALS_GENERATED_PATH" \
   --dry-run=client -o yaml \
   | kubectl apply -f - \
   2>&1 >/dev/null
cleanup

