#!/bin/bash


#######################################################################################
### PURPOSE
### 

# Install flux in radix cluster.


#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ZONE_ENV          : Path to *.env file
# - CLUSTER_NAME            : Ex: "test-2", "weekly-93"

# Optional:
# - GIT_REPO                : Default to radix-flux
# - GIT_BRANCH              : Default to "master"
# - GIT_DIR                 : Default to "development-configs"
# - USER_PROMPT             : Is human interaction is required to run script? true/false. Default is true.


#######################################################################################
### HOW TO USE
### 

# Normal usage
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./install_flux.sh

# Configure a dev cluster to use custom configs
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" GIT_BRANCH=my-test-configs GIT_DIR=my-test-directory ./install_flux.sh


#######################################################################################
### DOCS
### 

# - https://github.com/fluxcd/flux/tree/master/chart/flux
# - https://github.com/equinor/radix-flux/


#######################################################################################
### COMPONENTS
### 

# - AZ keyvault
#     Holds git deploy key to config repo
# - Flux CRDs
#     The CRDs are no longer in the Helm chart and must be installed separately
# - Flux Helm Chart
#     Installs everything else 


#######################################################################################
### START
### 

echo ""
echo "Start installing Flux..."


#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting...";  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nError: kubectl not found in PATH. Exiting...";  exit 1; }
hash helm 2> /dev/null  || { echo -e "\nError: helm not found in PATH. Exiting...";  exit 1; }
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

# Optional inputs

FLUX_PRIVATE_KEY_NAME="flux-github-deploy-key-private"
FLUX_PUBLIC_KEY_NAME="flux-github-deploy-key-public"
FLUX_DEPLOY_KEYS_GENERATED=false
FLUX_HELM_CRD_PATH="https://raw.githubusercontent.com/fluxcd/flux/helm-0.10.1/deploy-helm/flux-helm-release-crd.yaml"

if [[ -z "$GIT_REPO" ]]; then
  GIT_REPO="git@github.com:equinor/radix-flux.git"
fi

if [[ -z "$GIT_BRANCH" ]]; then
  GIT_BRANCH="master"
  GIT_DIR="development-configs"
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi


#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION" >/dev/null
printf "Done.\n"


#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Install Flux will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $AZ_RESOURCE_KEYVAULT"
echo -e "   -  GIT_REPO                         : $GIT_REPO"
echo -e "   -  GIT_BRANCH                       : $GIT_BRANCH"
echo -e "   -  GIT_DIR                          : $GIT_DIR"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $AZ_SUBSCRIPTION"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    read -p "Is this correct? (Y/n) " -n 1 -r
    if [[ "$REPLY" =~ (N|n) ]]; then
    echo ""
    echo "Quitting."
    exit 0
    fi
    echo ""
fi

echo ""



#######################################################################################
### CLUSTER?
###

kubectl_context="$(kubectl config current-context)"

if [ "$kubectl_context" = "$CLUSTER_NAME" ] || [ "$kubectl_context" = "${CLUSTER_NAME}-admin" ]; then
   echo "kubectl is ready..."
else
   echo "Please set your kubectl current-context to be $CLUSTER_NAME"
   exit 1
fi


#######################################################################################
### CREDENTIALS
###

FLUX_PRIVATE_KEY="$(az keyvault secret show --name "$FLUX_PRIVATE_KEY_NAME" --vault-name "$AZ_RESOURCE_KEYVAULT")"
FLUX_PUBLIC_KEY="$(az keyvault secret show --name "$FLUX_PUBLIC_KEY_NAME" --vault-name "$AZ_RESOURCE_KEYVAULT")"

if [[ -z "$FLUX_PRIVATE_KEY" ]] || [[ -z "$FLUX_PUBLIC_KEY" ]]; then
    echo "Missing flux deploy keys for GitHub in keyvault: $AZ_RESOURCE_KEYVAULT"
    echo "Generating flux private and public keys..."
    ssh-keygen -t rsa -b 4096 -N "" -C "gm_radix@equinor.com" -f id_rsa."$RADIX_ENVIRONMENT"
    az keyvault secret set --file=./id_rsa."$RADIX_ENVIRONMENT" --name="$FLUX_PRIVATE_KEY_NAME" --vault-name="$AZ_RESOURCE_KEYVAULT"
    az keyvault secret set --file=./id_rsa."$RADIX_ENVIRONMENT".pub --name="$FLUX_PUBLIC_KEY_NAME" --vault-name="$AZ_RESOURCE_KEYVAULT"
    rm id_rsa."$RADIX_ENVIRONMENT"
    rm id_rsa."$RADIX_ENVIRONMENT".pub
    FLUX_DEPLOY_KEYS_GENERATED=true
else
    echo "Found Flux deploy keys for GitHub in keyvault: $AZ_RESOURCE_KEYVAULT"
fi

echo ""
echo "Creating $FLUX_PRIVATE_KEY_NAME secret"
az keyvault secret download \
    --vault-name $AZ_RESOURCE_KEYVAULT \
    --name "$FLUX_PRIVATE_KEY_NAME" \
    --file "$FLUX_PRIVATE_KEY_NAME" \
    2>&1 >/dev/null

kubectl create secret generic "$FLUX_PRIVATE_KEY_NAME" \
   --from-file=identity="$FLUX_PRIVATE_KEY_NAME" \
   --dry-run -o yaml \
   | kubectl apply -f - \
   2>&1 >/dev/null

rm "$FLUX_PRIVATE_KEY_NAME"


#######################################################################################
### INSTALLATION

echo ""
echo "Adding Weaveworks repository to Helm"
helm repo add fluxcd https://fluxcd.github.io/flux

echo ""
echo "Adding Flux CRDs, no longer included in the helm chart"
kubectl apply -f "$FLUX_HELM_CRD_PATH" 2>&1 >/dev/null

echo ""
echo "Installing Flux with Helm operator"
helm upgrade --install flux \
   --set rbac.create=true \
   --set helmOperator.create=true \
   --set helmOperator.pullSecret=radix-docker \
   --set git.url="$GIT_REPO" \
   --set git.branch="$GIT_BRANCH" \
   --set git.path="$GIT_DIR" \
   --set git.secretName="$FLUX_PRIVATE_KEY_NAME" \
   --set registry.acr.enabled=true \
   --set prometheus.enabled=true \
   --set manifestGeneration=true \
   --set registry.excludeImage="k8s.gcr.io/*\,aksrepos.azurecr.io/*\,quay.io/*" \
   fluxcd/flux \
   2>&1 >/dev/null

echo -e ""
echo -e "A Flux service has been provisioned in the cluster to follow the GitOps way of thinking."

if [ "$FLUX_DEPLOY_KEYS_GENERATED" = true ]; then
    FLUX_DEPLOY_KEY_NOTIFICATION="*** IMPORTANT ***\nPlease add a new deploy key in the radix-flux repository (https://github.com/equinor/radix-flux/settings/keys) with the value from $FLUX_PUBLIC_KEY_NAME secret in $AZ_RESOURCE_KEYVAULT Azure keyvault."
    echo ""
    echo -e "${__style_yellow}$FLUX_DEPLOY_KEY_NOTIFICATION${__style_end}"
    echo ""
fi


#######################################################################################
### END
###

echo "Install of Flux is done!"
echo ""