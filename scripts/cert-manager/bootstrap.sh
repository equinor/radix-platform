#!/usr/bin/env bash


#######################################################################################
### PURPOSE
### 

# Bootstrap cert-manager in a radix cluster, v1.1


#######################################################################################
### PRECONDITIONS
### 

# - AKS cluster is available
# - User has role cluster-admin
# - Helm RBAC is configured in cluster


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
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./bootstrap.sh

#######################################################################################
### DOCS
###

# - https://cert-manager.io/docs/installation/helm/


#######################################################################################
### START
### 

echo ""
echo "Start bootstrap of cert-manager... "


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
echo -e "Bootstrap of cert-manager will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  CLUSTER_NAME                      : $CLUSTER_NAME"
echo -e "   -  AZ_RESOURCE_DNS                   : $AZ_RESOURCE_DNS"
echo -e "   -  RADIX_ZONE                        : $RADIX_ZONE"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                   : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                           : $(az account show --query user.name -o tsv)"
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
### Install cert-manager
###

printf "\nCreating cert-manager namespace and secret for flux-chart...\n"

# Create the namespace for cert-manager
kubectl create namespace cert-manager \
2>&1 >/dev/null

# Create secret for flux

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: cert-manager-certificate-values
  namespace: flux-system
type: Opaque
stringData:
  AZ_RESOURCE_DNS: ${AZ_RESOURCE_DNS}
  AZ_SUBSCRIPTION_ID: ${AZ_SUBSCRIPTION_ID}
  AZ_RESOURCE_GROUP_COMMON: ${AZ_RESOURCE_GROUP_COMMON}
EOF

echo ""
printf "Bootstrapping of Cert-Manager done!\n"
