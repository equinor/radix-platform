#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Install required base components in a radix cluster.

#######################################################################################
### PRECONDITIONS
###

# It is assumed that cluster is installed using the aks/bootstrap.sh script

# We don't use Helm to add extra resources any more. Instead we use three different methods:
# For resources that don't need any change: yaml file in manifests/ directory
# Resources that need non-secret customizations: inline the resource in this script and use environment variables
# Resources that need secret values: store the entire yaml file in Azure KeyVault

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV              : Path to *.env file
# - CLUSTER_NAME                : Ex: "test-2", "weekly-93"

# Optional:
# - MIGRATION_STRATEGY          : Relevant for ingress-nginx bootstrap. Ex: "aa", "at".
# - OVERRIDE_GIT_BRANCH         : Relevant for Flux bootstrap. Ex: "testing-branch"
# - OVERRIDE_GIT_DIR            : Relevant for Flux bootstrap. Ex: "clusters/testing-dir"
# - USER_PROMPT                 : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# Normal usage
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./install_base_components.sh

# Specify migration strategy.
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" MIGRATION_STRATEGY="aa" ./install_base_components.sh

# Configure a dev cluster to use custom configs
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="please-work-4" FLUX_OVERRIDE_GIT_BRANCH=testing-something FLUX_OVERRIDE_GIT_DIR=clusters/test-overlay ./install_base_components.sh

#######################################################################################
### START
###

echo ""
echo "Start install of base components... "

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
hash htpasswd 2>/dev/null || {
  echo -e "\nERROR: htpasswd not found in PATH. Exiting..." >&2
  exit 1
}
hash sqlcmd 2>/dev/null || {
  echo -e "\nERROR: sqlcmd not found in PATH. Exiting..." >&2
  exit 1
}
printf "All is good."
echo ""

#######################################################################################
### Read inputs and configs
###

# Overridable input
FLUX_GITOPS_BRANCH_OVERRIDE=$FLUX_GITOPS_BRANCH
FLUX_GITOPS_DIR_OVERRIDE=$FLUX_GITOPS_DIR

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
echo -e "Install base components will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  RADIX_API_PREFIX                 : $RADIX_API_PREFIX"
echo -e "   -  RADIX_WEBHOOK_PREFIX             : $RADIX_WEBHOOK_PREFIX"
if [ -n "$FLUX_OVERRIDE_GIT_BRANCH" ]; then
echo -e "   -  FLUX_OVERRIDE_GIT_BRANCH         : $FLUX_OVERRIDE_GIT_BRANCH"
fi
if [ -n "$FLUX_OVERRIDE_GIT_DIR" ]; then
echo -e "   -  FLUX_OVERRIDE_GIT_DIR            : $FLUX_OVERRIDE_GIT_DIR"
fi
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
  while true; do
    read -r -p "Is this correct? (Y/n) " yn
    case $yn in
      [Yy]* ) break;;
      [Nn]* ) echo ""; echo "Quitting."; exit 0;;
      * ) echo "Please answer yes or no.";;
    esac
  done
fi

echo ""

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "\nConnecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {
  # Send message to stderr
  echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
  exit 0
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
verify_cluster_access

#######################################################################################
### Create flux namespace
###
if [[ $(kubectl get namespace flux-system 2>&1) == *"Error"* ]];then
    printf "\nCreating flux-system namespace..."
    kubectl create namespace flux-system 2>&1 >/dev/null
    printf "...Done"
fi

#######################################################################################
### Add priority classes
###

echo ""
kubectl apply --filename ./priority-classes/radixComponentPriorityClass.yaml
wait

#######################################################################################
### Install ingress-nginx
###

(MIGRATION_STRATEGY="${MIGRATION_STRATEGY}" USER_PROMPT="false" ./ingress-nginx/bootstrap.sh)
wait

#######################################################################################
### Install cert-manager
###

(USER_PROMPT="false" ./cert-manager/bootstrap.sh)
wait

#######################################################################################
### Create storage classes
###

echo "Creating storage classes"
kubectl apply --filename manifests/storageclass-retain.yaml
kubectl apply --filename manifests/storageclass-retain-nocache.yaml

#######################################################################################
### Install grafana
###

echo ""
(USER_PROMPT="$USER_PROMPT" ./grafana/bootstrap.sh)
wait

#######################################################################################
### Install prerequisites for external-dns (flux handles the main installation)
###

echo ""
(./external-dns-prerequisites/bootstrap.sh)
wait

#######################################################################################
### For network security policy applied by operator to work, the namespace hosting prometheus and nginx-ingress-controller need to be labeled
kubectl label ns default purpose=radix-base-ns --overwrite

#######################################################################################
# Create radix platform shared configs and secrets
# Create 3 secrets for Radix platform radix-sp-acr-azure, radix-docker and radix-snyk-service-account

echo ""
echo "Start on radix platform shared configs and secrets..."

echo ""
(./config-and-secrets/bootstrap-acr.sh)
(USER_PROMPT="$USER_PROMPT" ./config-and-secrets/bootstrap-snyk.sh)
wait

echo "Done."

#######################################################################################
# Bootstrap snyk-monitor
# NOTE: Depends on radix-docker secret, created in scripts/config-and-secrets/bootstrap-acr.sh

echo ""
(USER_PROMPT="$USER_PROMPT" ./snyk-monitor/bootstrap.sh)
wait

#######################################################################################
### Install Radix CICD Canary
###

echo ""
(./cicd-canary/bootstrap.sh)
wait

#######################################################################################
### Install Radix cost exporter
###

echo ""
(./cost-allocation/bootstrap.sh)
wait

#######################################################################################
### Install Radix vulnerability scanner
###

echo ""
(./vulnerability-scanner/bootstrap.sh)
wait

#######################################################################################
### Deploy dynatrace
###

#echo ""
#(./dynatrace/bootstrap.sh)
#wait

#######################################################################################
### Install prerequisites for Velero
###

echo ""
(USER_PROMPT="$USER_PROMPT" ./velero/install_prerequisites_in_cluster.sh)
wait

#######################################################################################
### Patching kube-dns metrics
###

# TODO: Even with this, kube-dns is not discovered in prometheus. Needs to be debugged.
#
# echo "Patching kube-dns metrics"
# kubectl patch deployment -n kube-system kube-dns-v20 \
#     --patch "$(cat ./manifests/kube-dns-metrics-patch.yaml)"

#

#######################################################################################
### Install Flux

echo ""
echo "Install Flux v2"
echo ""

(USER_PROMPT="$USER_PROMPT" \
  RADIX_ZONE_ENV="$RADIX_ZONE_ENV" \
  CLUSTER_NAME="$CLUSTER_NAME" \
  OVERRIDE_GIT_BRANCH="$FLUX_OVERRIDE_GIT_BRANCH" \
  OVERRIDE_GIT_DIR="$FLUX_OVERRIDE_GIT_DIR" \
  ./flux/bootstrap.sh)
wait

#######################################################################################
### END
###

echo ""
echo "Install of base components is done!"
echo ""
