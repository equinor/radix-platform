#!/bin/bash


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
# - Tiller is installed in cluster (if using Helm version < 2)


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
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" ./bootstrap.sh

# STAGING
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-2" STAGING=true ./bootstrap.sh


#######################################################################################
### DOCS
###

# - https://docs.cert-manager.io/en/release-0.11/getting-started/install/kubernetes.html


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
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting...";  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nError: kubectl not found in PATH. Exiting...";  exit 1; }
hash helm 2> /dev/null  || { echo -e "\nError: helm not found in PATH. Exiting...";  exit 1; }
hash jq 2> /dev/null  || { echo -e "\nError: jq not found in PATH. Exiting...";  exit 1; }
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
echo -e "Bootstrap of cert-manager will use the following configuration:"
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
### Install cert-manager
###

function installCertManager(){
    printf "\nInstalling cert-manager..."
    # Install the CustomResourceDefinition resources separately
    #kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.11/deploy/manifests/00-crds.yaml \
    #2>&1 >/dev/null

    # Create the namespace for cert-manager
    kubectl create namespace cert-manager \
    2>&1 >/dev/null

    # Add the Jetstack Helm repository
    helm repo add jetstack https://charts.jetstack.io \
    2>&1 >/dev/null

    # Update your local Helm chart repository cache
    helm repo update \
    2>&1 >/dev/null

    # Install the cert-manager Helm chart 
    #
    # Regarding ingress, see https://cert-manager.io/docs/usage/ingress/
    helm upgrade --install cert-manager \
    --namespace cert-manager \
    --version v1.2.0 \
    --set installCRDs=true \
    --set global.rbac.create=true \
    --set ingressShim.defaultIssuerName="$CERT_ISSUER" \
    --set ingressShim.defaultIssuerKind=ClusterIssuer \
    jetstack/cert-manager \
    2>&1 >/dev/null
    printf "...Done.\n"
}


#######################################################################################
### Transform and apply all custom resources
###

function transformManifests() {
    printf "\nStart transforming manifests..."
    # Fetch dns system user credentials
    # Read secret, extract stringified json from property "value" and convert it into json
    local DNS_SP="$(az keyvault secret show \
        --vault-name $AZ_RESOURCE_KEYVAULT \
        --name $AZ_SYSTEM_USER_DNS \
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
    printf "\nStart applying manifests..."
    local TMP_DIR="${WORK_DIR}/tmp"
    kubectl apply -f "${TMP_DIR}/translated-manifests.yaml"
    rm -rf "${TMP_DIR}"
    printf "...Done.\n"
}

function annotateSecretsForKubedSync() {
    printf "\nAnnotating tls secrets for Kubed sync..."

    local isAllSecretsAnnotated="false"

    while [[ "$isAllSecretsAnnotated"  == "false" ]]; do

        isAllSecretsAnnotated="true"

        if [[ "$(kubectl annotate --overwrite Secret app-wildcard-tls-cert kubed.appscode.com/sync='app-wildcard-sync=app-wildcard-tls-cert' 2>&1)" == *"Error" ]]; then
            isAllSecretsAnnotated="false"
        else
            printf "annotated app-wildcard-tls-cert..."
        fi

        if [[ "$(kubectl annotate --overwrite Secret cluster-wildcard-tls-cert kubed.appscode.com/sync='cluster-wildcard-sync=cluster-wildcard-tls-cert' 2>&1)" == *"Error" ]]; then
            isAllSecretsAnnotated="false"
        else
            printf "annotated cluster-wildcard-tls-cert..."
        fi

        if [[ "$(kubectl annotate --overwrite Secret active-cluster-wildcard-tls-cert kubed.appscode.com/sync='active-cluster-wildcard-sync=active-cluster-wildcard-tls-cert' 2>&1)" == *"Error" ]]; then
            isAllSecretsAnnotated="false"
        else
            printf "annotated active-cluster-wildcard-tls-cert..."
        fi

        printf "."
        sleep 3

    done

    printf "...Done\n"
}


#######################################################################################
### MAIN
###

installCertManager
sleep 60
transformManifests
applyManifests
annotateSecretsForKubedSync


#######################################################################################
### END
###

echo ""
echo "Bootstrapping of Cert-Manager done!"
