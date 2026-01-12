#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Install flux in radix cluster.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE              : dev|playground|prod|c2
# - CLUSTER_NAME            : Ex: "test-2", "weekly-93"
# - GIT_REPO                : Ex: "ssh://git@github.com/equinor/radix-flux"
# - GIT_BRANCH              : Ex: "master"
# - GIT_DIR                 : Ex: "clusters/development"

# Optional:
# - USER_PROMPT             : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# Normal usage
# RADIX_ZONE=dev CLUSTER_NAME="cilium-26" ./bootstrap.sh

# Configure a dev cluster to use custom configs
# RADIX_ZONE=dev CLUSTER_NAME="cilium-26" OVERRIDE_GIT_BRANCH=my-test-configs OVERRIDE_GIT_DIR=my-test-directory ./bootstrap.sh

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
hash flux 2>/dev/null || {
    echo -e "\nERROR: flux not found in PATH. Exiting..." >&2
    exit 1
}
printf "All is good."
echo ""

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2|c3)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2|c3" >&2
    exit 1
fi

if [[ ! -z "$OVERRIDE_GIT_BRANCH" ]]; then
    GIT_BRANCH="$OVERRIDE_GIT_BRANCH"
fi

if [[ ! -z "$OVERRIDE_GIT_DIR" ]]; then
    GIT_DIR="$OVERRIDE_GIT_DIR"
fi

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "ERROR: Please provide CLUSTER_NAME" >&2
    exit 1
fi

if [[ -z "$GIT_REPO" ]]; then
    echo "ERROR: Please provide GIT_REPO" >&2
    exit 1
fi

if [[ -z "$GIT_BRANCH" ]]; then
    echo "ERROR: Please provide GIT_BRANCH" >&2
    exit 1
fi

if [[ -z "$GIT_DIR" ]]; then
    echo "ERROR: Please provide GIT_DIR" >&2
    exit 1
fi

if [[ -z "$FLUX_VERSION" ]]; then
    echo "ERROR: Please provide FLUX_VERSION" >&2
    exit 1
fi

FLUX_LOCAL="$(flux version -ojson | jq -r .flux)"

# Source util scripts
RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Flux vars

FLUX_PRIVATE_KEY_NAME="flux-github-deploy-key-private"
FLUX_PUBLIC_KEY_NAME="flux-github-deploy-key-public"
FLUX_DEPLOY_KEYS_GENERATED=false

#######################################################################################
### Environment
###
printf "\n%s► Read YAML configfile $RADIX_ZONE"
RADIX_ZONE_ENV=$(config_path $RADIX_ZONE)
printf "\n%s► Read terraform variables and configuration"
RADIX_RESOURCE_JSON=$(environment_json $RADIX_ZONE)
RADIX_ZONE_YAML=$(cat <<EOF
$(<$RADIX_ZONE_ENV)
EOF
)
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_KEYVAULT=$(jq -r .keyvault <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_CONTAINER_REGISTRY=$(jq -r .acr <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")
AZ_RADIX_ZONE_LOCATION=$(yq '.location' <<< "$RADIX_ZONE_YAML")
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
echo -e "Install Flux v2 will use the following configuration:"
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
echo -e "   -  FLUX_VERSION                     : $FLUX_VERSION"
echo -e "   -  FLUX_LOCAL                       : $FLUX_LOCAL"
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
        [Yy]*) break ;;
        [Nn]*)
            echo ""
            echo "Quitting."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
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
    exit 0
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###

verify_cluster_access

printf "\nWorking on namespace..."
if [[ $(kubectl get namespace flux-system 2>&1) == *"Error"* ]]; then
    kubectl create ns flux-system 2>&1 >/dev/null
fi
printf "...Done"

#######################################################################################
### Install Flux
echo ""
echo "Install Flux v2"
echo ""
FLUX_PRIVATE_KEY_NAME="flux-github-deploy-key-private"
FLUX_PRIVATE_KEY="$(az keyvault secret show --name "$FLUX_PRIVATE_KEY_NAME" --vault-name "$AZ_RESOURCE_KEYVAULT")"

echo "Creating \"radix-flux-config\"..."

printf "\nGetting Slack Webhook URL..."
SLACK_WEBHOOK_URL="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name slack-webhook | jq -r .value)"
printf "...Done\n"

printf "\nWorking on namespace flux-system"
if [[ $(kubectl get namespace flux-system 2>&1) == *"Error"* ]]; then
    kubectl create ns flux-system 2>&1 >/dev/null
fi
printf "...Done"

# Create configmap for Flux v2 to use for variable substitution. (https://fluxcd.io/docs/components/kustomize/kustomization/#variable-substitution)
printf "Deploy \"radix-flux-config\" configmap in flux-system namespace..."
kubectl create configmap radix-flux-config -n flux-system \
    --from-literal=dnsZone="$AZ_RESOURCE_DNS" \
    --from-literal=appAliasBaseURL="app.$AZ_RESOURCE_DNS" \
    --from-literal=prometheusName="radix-stage1" \
    --from-literal=imageRegistry="$IMAGE_REGISTRY" \
    --from-literal=clusterName="$CLUSTER_NAME" \
    --from-literal=clusterType="$(yq '.cluster_type' <<< "$RADIX_ZONE_YAML")" \
    --from-literal=slackWebhookURL="$SLACK_WEBHOOK_URL"
printf "...Done.\n"

az keyvault secret download \
--vault-name "$AZ_RESOURCE_KEYVAULT" \
--name "$FLUX_PRIVATE_KEY_NAME" \
--file "$FLUX_PRIVATE_KEY_NAME" 2>&1 >/dev/null

echo "Installing flux with your flux version: v$FLUX_VERSION"
flux bootstrap git \
--private-key-file="$FLUX_PRIVATE_KEY_NAME" \
--url="ssh://git@github.com/equinor/radix-flux" \
--branch="$OVERRIDE_GIT_BRANCH" \
--path="clusters/$(yq '.flux_folder' <<< "$RADIX_ZONE_YAML")" \
--components-extra=image-reflector-controller,image-automation-controller \
--version="v$FLUX_VERSION" \
--silent
if [[ "$?" != "0" ]]; then
    printf "\nERROR: flux bootstrap git failed. Exiting...\n" >&2
    rm "$FLUX_PRIVATE_KEY_NAME"
    exit 1
else
    rm "$FLUX_PRIVATE_KEY_NAME"
    echo " Done."
fi

echo -e ""
echo -e "A Flux service has been provisioned in the cluster to follow the GitOps way of thinking."


#######################################################################################
### END
###

echo "Bootstrap of Flux is done!"
echo ""
