#!/bin/bash

#######################################################################################
### PURPOSE
###

# Bootstrap prerequisites for velero (flux handles the main installation)

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
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./install_cluster_prerequisites.sh

#######################################################################################
### START
###

echo ""
echo "Start prerequisites for velero..."

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
CREDENTIALS_TEMPLATE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/template_credentials.env"
if [[ ! -f "$CREDENTIALS_TEMPLATE_PATH" ]]; then
   echo "The dependency CREDENTIALS_TEMPLATE_PATH=$CREDENTIALS_TEMPLATE_PATH is invalid, the file does not exist." >&2
   exit 1
fi

# Get velero env vars
source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/velero.env"


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
    local SP_JSON="$(az keyvault secret show \
        --vault-name $AZ_RESOURCE_KEYVAULT \
        --name $AZ_VELERO_SERVICE_PRINCIPAL_NAME \
        | jq '.value | fromjson')"

    # Set variables used in the manifest templates
    local AZURE_SUBSCRIPTION_ID="$AZ_SUBSCRIPTION_ID"
    local AZURE_CLIENT_ID="$(echo $SP_JSON | jq -r '.id')"
    local AZURE_TENANT_ID="$(echo $SP_JSON | jq -r '.tenantId')"
    local AZURE_CLIENT_SECRET="$(echo $SP_JSON | jq -r '.password')"

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
kubectl create secret generic cloud-credentials --namespace "$VELERO_NAMESPACE" \
   --from-env-file="$CREDENTIALS_GENERATED_PATH" \
   --dry-run -o yaml \
#   | kubectl apply -f - \
#   2>&1 >/dev/null
cleanup
