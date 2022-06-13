#!/usr/bin/env bash


#######################################################################################
### PURPOSE
### 

# Move custom ingresses from one cluster to another

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
# - SOURCE_CLUSTER      : Ex: "test-2", "weekly-93"
# - DEST_CLUSTER        : Ex: "test-2", "weekly-93"


#######################################################################################
### HOW TO USE
### 

# Option #1 - migrate ingresses from source to destination cluster
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env SOURCE_CLUSTER="weekly-2" DEST_CLUSTER="weekly-3" ./move_custom_ingresses.sh

# Option #2 - configure ingresses from destination cluster only. Useful when creating cluster form scratch
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env DEST_CLUSTER="weekly-3" ./move_custom_ingresses.sh


#######################################################################################
### START
### 
echo ""
echo "Start moving custom ingresses..."


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

if [[ -z "$DEST_CLUSTER" ]]; then
    echo "ERROR: Please provide DEST_CLUSTER" >&2
    exit 1
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

if [[ -z "$SOURCE_CLUSTER" ]]; then
    echo "ERROR: SOURCE_CLUSTER is not defined" >&2
    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -r -p "Is this intentional? (Y/n) " yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) echo ""; echo "Quitting."; exit 0;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
fi


#######################################################################################
### Resolve dependencies on other scripts
###

WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BOOTSTRAP_APP_ALIAS_SCRIPT="$WORKDIR_PATH/app_alias/bootstrap.sh"
if ! [[ -x "$BOOTSTRAP_APP_ALIAS_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The create alias script is not found or it is not executable in path $BOOTSTRAP_APP_ALIAS_SCRIPT" >&2
fi

#######################################################################################
### Define web console auth secret variables
###

AUTH_PROXY_COMPONENT="auth"
AUTH_PROXY_REPLY_PATH="/oauth2/callback"
RADIX_WEB_CONSOLE_ENV="prod"
if [[ $CLUSTER_TYPE  == "development" ]]; then
    RADIX_WEB_CONSOLE_ENV="qa"
fi
AUTH_INGRESS_SUFFIX=".custom-domain"
WEB_CONSOLE_NAMESPACE="radix-web-console-$RADIX_WEB_CONSOLE_ENV"

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
echo -e "Move custom ingresses will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  SOURCE_CLUSTER                   : $SOURCE_CLUSTER"
echo -e "   -  DEST_CLUSTER                     : $DEST_CLUSTER"
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
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS"  --name "$DEST_CLUSTER" 2>&1)"" == *"ERROR"* ]]; then    
    # Send message to stderr
    echo -e "ERROR: Cluster \"$DEST_CLUSTER\" not found." >&2
    exit 1
fi
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
printf "Verifying cluster access..."
if [[ $(kubectl cluster-info 2>&1) == *"Unable to connect to the server"* ]]; then
    printf "ERROR: Could not access cluster. Quitting...\n" >&2
    exit 1
fi
printf " OK\n"

#######################################################################################
### Move custom ingresses
###
echo ""
printf "Enabling monitoring addon in the destination cluster... "
WORKSPACE_ID=$(az resource list --resource-type Microsoft.OperationalInsights/workspaces --name "${AZ_RESOURCE_LOG_ANALYTICS_WORKSPACE}" --subscription "${AZ_SUBSCRIPTION_ID}" --query "[].id" --output tsv)
az aks enable-addons --addons monitoring --name "${DEST_CLUSTER}" --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" --workspace-resource-id "${WORKSPACE_ID}" --no-wait
printf "Done.\n"

if [[ -n "${SOURCE_CLUSTER}" ]]; then
    echo ""
    printf "Disabling monitoring addon in the source cluster... "
    az aks disable-addons --addons monitoring --name "${SOURCE_CLUSTER}" --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" --subscription "${AZ_SUBSCRIPTION_ID}" --no-wait
    printf "Done.\n"

    #######################################################################################
    ### Change credentials to Source cluster
    ###

    echo ""
    printf "Point to source cluster... "
    az aks get-credentials --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" --name "${SOURCE_CLUSTER}" \
        --overwrite-existing \
        --admin \
        2>&1 >/dev/null
    [[ "$(kubectl config current-context)" != "${SOURCE_CLUSTER}-admin" ]] && exit 1
    printf "Done.\n"

    echo ""
    printf "Delete custom ingresses... "
    while read -r line; do
        if [[ "$line" ]]; then
            helm delete "${line}"
        fi
    done <<<"$(helm list --short | grep radix-ingress)"

    #######################################################################################
    ### 
    ###
    # Point grafana to cluster specific ingress
    GRAFANA_ROOT_URL="https://grafana.$SOURCE_CLUSTER.$AZ_RESOURCE_DNS"
    kubectl set env deployment/grafana GF_SERVER_ROOT_URL="$GRAFANA_ROOT_URL"

    #######################################################################################
    ### Scale down source cluster resources
    ###
    echo ""
    printf "Scale down radix-cicd-canary in %s...\n" "$SOURCE_CLUSTER"
    kubectl scale deployment --namespace radix-cicd-canary radix-cicd-canary --replicas=0
    wait
    printf "Done.\n"

    #######################################################################################
    ### Suspend source flux resources
    ###
    echo ""
    printf "Suspend radix-cicd-canary kustomizations...\n"
    flux suspend kustomization radix-cicd-canary
    wait
    printf "Done.\n"

    printf "Update Auth proxy secret...\n"
    (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" AUTH_PROXY_COMPONENT="$AUTH_PROXY_COMPONENT" WEB_CONSOLE_NAMESPACE="$WEB_CONSOLE_NAMESPACE" AUTH_PROXY_REPLY_PATH="$AUTH_PROXY_REPLY_PATH" ./update_auth_proxy_secret_for_console.sh)
    printf "Done.\n"
fi

#######################################################################################
### Change credentials to Destination cluster
###

echo ""
printf "Point to destination cluster... "
az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$DEST_CLUSTER"
[[ "$(kubectl config current-context)" != "$DEST_CLUSTER-admin" ]] && exit 1

echo ""
printf "Create aliases in destination cluster... "
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$DEST_CLUSTER" USER_PROMPT="$USER_PROMPT" source "$BOOTSTRAP_APP_ALIAS_SCRIPT")
wait # wait for subshell to finish
printf "Done creating aliases."

# Update auth proxy secret and redis cache
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" AUTH_PROXY_COMPONENT="$AUTH_PROXY_COMPONENT" AUTH_INGRESS_SUFFIX="$AUTH_INGRESS_SUFFIX" WEB_CONSOLE_NAMESPACE="$WEB_CONSOLE_NAMESPACE" AUTH_PROXY_REPLY_PATH="$AUTH_PROXY_REPLY_PATH" ./update_auth_proxy_secret_for_console.sh)
wait # wait for subshell to finish

# Point granana to cluster type ingress
echo "Update grafana reply-URL... "
# Transform clustername to lowercase
CLUSTER_NAME_LOWER="$(echo "$DEST_CLUSTER" | awk '{print tolower($0)}')"
GF_SERVER_ROOT_URL="https://grafana.$AZ_RESOURCE_DNS"

printf "Update grafana-helm-secret... "

echo "ingress:
  enabled: true
  hosts:
  - grafana.$CLUSTER_NAME_LOWER.$AZ_RESOURCE_DNS
  tls:
  - secretName: cluster-wildcard-tls-cert
    hosts:
    - grafana.$CLUSTER_NAME_LOWER.$AZ_RESOURCE_DNS
env:
  GF_SERVER_ROOT_URL: $GF_SERVER_ROOT_URL" > config

kubectl create secret generic grafana-helm-secret \
    --from-file=./config \
    --dry-run=client -o yaml |
    kubectl apply -f -

rm -f config

printf "Update grafana deployment... "
kubectl set env deployment/grafana GF_SERVER_ROOT_URL="$GF_SERVER_ROOT_URL"

echo ""
echo "Grafana reply-URL has been updated."

echo ""
echo "###########################################################"
echo ""
echo "NOTE: You need to manually activate the cluster"
echo ""
echo "You do this in the https://github.com/equinor/radix-flux repo"
echo ""
echo "###########################################################"

echo ""
echo "###########################################################"
echo ""
echo "NOTE: If radix-cicd-canary does not work properly,"
echo "there may be app alias DNS entries for the old cluster"
echo "(e.g. app-canarycicd-test2-prod.playground.radix.equinor.com)."
echo "Delete these DNS entries in Azure DNS!"
echo ""
echo "###########################################################"
