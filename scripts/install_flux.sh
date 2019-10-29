#!/bin/bash


#######################################################################################
### PURPOSE
### 

# Install flux in radix cluster.


#######################################################################################
### INPUTS
### 

# Required:
# - RADIX_ENVIRONMENT       : "prod" || "dev"
# - AZ_RESOURCE_KEYVAULT    : Ex: "radix-vault-dev"
# - CLUSTER_NAME            : Ex: "test-2", "weekly-93".

# Optional:
# - GIT_REPO                : Default to radix-flux
# - GIT_BRANCH              : Default to "master"
# - GIT_DIR                 : Default to "development-configs"


#######################################################################################
### HOW TO USE
### 

#   RADIX_ENVIRONMENT=dev AZ_RESOURCE_KEYVAULT="radix-vault-dev" CLUSTER_NAME=weekly-10 ./install_flux.sh

# When you want to use your own custom configs then provide git branch and directory
#   RADIX_ENVIRONMENT=dev CLUSTER_NAME=weekly-10 GIT_BRANCH=my-test-configs GIT_DIR=my-test-directory ./install_flux.sh


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
### Read inputs and configs
###

# Required inputs

if [[ -z "$RADIX_ENVIRONMENT" ]]; then
    echo "Please provide RADIX_ENVIRONMENT. Value must be one of: \"prod\", \"dev\"." >&2
    exit 1
fi

if [[ -z "$AZ_RESOURCE_KEYVAULT" ]]; then
    echo "Please provide AZ_RESOURCE_KEYVAULT." >&2
    exit 1
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME." >&2
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



#######################################################################################
### Output settings
###

echo "Installing Flux with the following settings:"
echo "   RADIX_ENVIRONMENT      : ${RADIX_ENVIRONMENT}"
echo "   AZ_RESOURCE_KEYVAULT   : ${AZ_RESOURCE_KEYVAULT}"
echo "   CLUSTER_NAME           : ${CLUSTER_NAME}"
echo "   GIT_REPO               : ${GIT_REPO}"
echo "   GIT_BRANCH             : ${GIT_BRANCH}"
echo "   GIT_DIR                : ${GIT_DIR}"


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

echo "Done."