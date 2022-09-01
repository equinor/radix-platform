#!/usr/bin/env bash


#######################################################################################
### PURPOSE
### 

# Tear down cert-manager in a radix cluster, v0.8.1


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

# Normal usage
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./teardown.sh


#######################################################################################
### DOCS
### 

# - https://docs.cert-manager.io/en/release-0.11/tasks/uninstall/kubernetes.html


#######################################################################################
### START
### 

echo ""
echo "Start tear down of cert-manager... "


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2;  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2;  exit 1; }
hash helm 2> /dev/null  || { echo -e "\nERROR: helm not found in PATH. Exiting..." >&2;  exit 1; }
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

# Script vars

WORK_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"



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
echo -e "Tear down of cert-manager will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  CERT-MANAGER                     : v0.8.1"
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
### MAIN
###

# Step 1: Remove all custom resources
#kubectl get Issuers,ClusterIssuers,Certificates,CertificateRequests,Orders,Challenges --all-namespaces
printf "\nDelete all custom resources..."
kubectl delete Issuers --all --all-namespaces 2>&1 >/dev/null
kubectl delete ClusterIssuers --all --all-namespaces 2>&1 >/dev/null
kubectl delete Certificates --all --all-namespaces 2>&1 >/dev/null
kubectl delete CertificateRequests --all --all-namespaces 2>&1 >/dev/null
kubectl delete Orders --all --all-namespaces 2>&1 >/dev/null
kubectl delete Challenges --all --all-namespaces 2>&1 >/dev/null
printf "...Done.\n"

# Step 2: Remove the helm release
printf "\nDelete and purge the helm release..."
helm delete cert-manager --purge 2>&1 >/dev/null
printf "...Done.\n"

# Step 3: Remove the namespace
printf "\nDelete the namespace..."
kubectl delete namespace cert-manager 2>&1 >/dev/null
printf "...Done.\n"

# Step 3.5: Making sure the webhook is really gone
printf "\nMaking sure the webhook is really gone..."
kubectl delete apiservice v1beta1.webhook.cert-manager.io 2>&1 >/dev/null
printf "...Done.\n"

# Step 4: Remove all the custom resource definitions
printf "\nDelete all the custom resource definitions..."
# If this step fails then look at https://docs.cert-manager.io/en/release-0.11/tasks/uninstall/kubernetes.html#namespace-stuck-in-terminating-state
kubectl delete -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml 2>&1 >/dev/null
printf "...Done.\n"


#######################################################################################
### END
###

echo ""
echo "Tear down of cert-manager is done!"
