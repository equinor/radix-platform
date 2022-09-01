#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Install prerequisites for velero (flux handles the main installation)


#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin
# - Velereo service principal credentials exist in keyvault


#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - CLUSTER_NAME        : Ex: "test-2", "weekly-93"

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.


#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=power-monkey ./install_prerequisites_in_cluster.sh


#######################################################################################
### START
###

echo ""
echo "Start install of Velero prerequisites in cluster..."


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

# Configs and dependencies
CREDENTIALS_GENERATED_PATH="$(mktemp)"
CREDENTIALS_TEMPLATE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/template_credentials.env"
if [[ ! -f "$CREDENTIALS_TEMPLATE_PATH" ]]; then
   echo "ERROR: The dependency CREDENTIALS_TEMPLATE_PATH=$CREDENTIALS_TEMPLATE_PATH is invalid, the file does not exist." >&2
   exit 1
fi

#######################################################################################
### Prepare az session
###

echo ""
printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done."
echo ""


#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Install Velero prequisistes in cluster will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e "   -  KUBECTL CURRENT CONTEXT          : $(kubectl config current-context)"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  VELERO_NAMESPACE                 : $VELERO_NAMESPACE"
echo -e "   -  APP_REGISTRATION_VELERO          : $APP_REGISTRATION_VELERO"
echo -e "   -  CREDENTIALS_TEMPLATE_PATH        : $CREDENTIALS_TEMPLATE_PATH"
echo -e "   -  BACKUP_STORAGE_CONTAINER         : $CLUSTER_NAME"
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
### MAIN
###

# 1. Download secret in shell var
# 2. Create tmp azure.json using template
# 3. Create namespace
# 4. Create k8s secret with azure.json as payload in namespace
# 5. Create configmap for flux deployments
# 6. Create the cluster specific blob container
# 7. Ensure that generated credentials file is deleted on local machine even if script crash

function cleanup() {
    rm -f "$CREDENTIALS_GENERATED_PATH"
}

function generateCredentialsFile() {
    local SP_JSON="$(az keyvault secret show \
        --vault-name $AZ_RESOURCE_KEYVAULT \
        --name $APP_REGISTRATION_VELERO \
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

printf "\nWorking on namespace..."
case "$(kubectl get ns $VELERO_NAMESPACE 2>&1)" in 
    *Error*)
        kubectl create ns "$VELERO_NAMESPACE" 2>&1 >/dev/null
    ;;
esac
printf "...Done"

printf "\nWorking on credentials..."
generateCredentialsFile
kubectl create secret generic cloud-credentials --namespace "$VELERO_NAMESPACE" \
   --from-file=cloud=$CREDENTIALS_GENERATED_PATH \
   --dry-run=client -o yaml \
   | kubectl apply -f - \
   2>&1 >/dev/null
printf "...Done"

# Create the cluster specific blob container
printf "\nWorking on storage container..."
az storage container create -n "$CLUSTER_NAME" \
  --public-access off \
  --account-name "$AZ_VELERO_STORAGE_ACCOUNT_ID" \
  --auth-mode login \
  2>&1 >/dev/null
printf "...Done"

# Velero custom RBAC clusterrole
RBAC_CLUSTERROLE="velero-admin"
printf "\nCreating $RBAC_CLUSTERROLE clusterrole..\n"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: $RBAC_CLUSTERROLE
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
rules:
- apiGroups:
  - "*"
  resources:
  - "*"
  verbs:
  - "*"
- nonResourceURLs: ["*"]
  verbs: ["*"]
EOF

# Create configMap that will hold the cluster specific values that Flux will later use when it manages the deployment of Velero
printf "Working on configmap for flux..."
cat <<EOF | kubectl apply -f - 2>&1 >/dev/null
apiVersion: v1
kind: ConfigMap
metadata:
  name: velero-flux-values
  namespace: $VELERO_NAMESPACE
data:
  values: |
    configuration:
      backupStorageLocation:
        bucket: $CLUSTER_NAME
        config:
          storageAccount: $AZ_VELERO_STORAGE_ACCOUNT_ID
EOF
printf "...Done"

printf "\nClean up local tmp files..."
cleanup
printf "...Done"


#######################################################################################
### END
###

echo -e ""
echo -e "Install of Velereo prerequisites done!"