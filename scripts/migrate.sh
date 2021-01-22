#!/bin/bash

#######################################################################################
### PURPOSE
###

# Migrate the radix platform from cluster to cluster

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - SOURCE_CLUSTER      : Ex: "test-2", "weekly-93"
# - DEST_CLUSTER        : Ex: "test-2", "weekly-93"

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env SOURCE_CLUSTER=beastmode-11 DEST_CLUSTER=mommas-boy-12 ./migrate.sh

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nError: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nError: kubectl not found in PATH. Exiting... " >&2
    exit 1
}
hash envsubst 2>/dev/null || {
    echo -e "\nError: envsubst not found in PATH. Exiting..." >&2
    exit 1
}
hash helm 2>/dev/null || {
    echo -e "\nError: helm not found in PATH. Exiting..." >&2
    exit 1
}
hash velero 2>/dev/null || {
    echo -e "\nError: velero not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nError: jq not found in PATH. Exiting..." >&2
    exit 1
}
hash htpasswd 2>/dev/null || {
  echo -e "\nError: htpasswd not found in PATH. Exiting..."
  exit 1
}
printf "Done.\n"

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

if [[ -z "$SOURCE_CLUSTER" ]]; then
    echo "Please provide SOURCE_CLUSTER" >&2
    exit 1
fi

if [[ -z "$DEST_CLUSTER" ]]; then
    echo "Please provide DEST_CLUSTER" >&2
    exit 1
fi

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Script vars

if [[ -z "$BACKUP_NAME" ]]; then
    BACKUP_NAME="migration-$(date '+%Y%m%d%H%M%S')"
fi

#######################################################################################
### Resolve dependencies on other scripts
###

WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BOOTSTRAP_AKS_SCRIPT="$WORKDIR_PATH/aks/bootstrap.sh"
if ! [[ -x "$BOOTSTRAP_AKS_SCRIPT" ]]; then
    # Print to stderror
    echo "The bootstrap script is not found or it is not executable in path $BOOTSTRAP_AKS_SCRIPT" >&2
fi

INSTALL_BASECOMPONENTS_SCRIPT="$WORKDIR_PATH/install_base_components.sh"
if ! [[ -x "$INSTALL_BASECOMPONENTS_SCRIPT" ]]; then
    # Print to stderror
    echo "The install base components script is not found or it is not executable in path $INSTALL_BASECOMPONENTS_SCRIPT" >&2
fi

RESTORE_APPS_SCRIPT="$WORKDIR_PATH/velero/restore/restore_apps.sh"
if ! [[ -x "$RESTORE_APPS_SCRIPT" ]]; then
    # Print to stderror
    echo "The restore apps script is not found or it is not executable in path $RESTORE_APPS_SCRIPT" >&2
fi

BOOTSTRAP_APP_ALIAS_SCRIPT="$WORKDIR_PATH/app_alias/bootstrap.sh"
if ! [[ -x "$BOOTSTRAP_APP_ALIAS_SCRIPT" ]]; then
    # Print to stderror
    echo "The create alias script is not found or it is not executable in path $BOOTSTRAP_APP_ALIAS_SCRIPT" >&2
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
echo -e "Migrate will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  RADIX_ENVIRONMENT                : $RADIX_ENVIRONMENT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
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
    read -p "Is this correct? (Y/n) " -n 1 -r
    if [[ "$REPLY" =~ (N|n) ]]; then
        echo ""
        echo "Quitting."
        exit 0
    fi
    echo ""
fi

echo ""

#--------------------------------------------------------

#######################################################################################
### Connect kubectl
###

# Exit if source cluster does not exist
echo ""
echo "Verifying source cluster existence..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$SOURCE_CLUSTER" 2>&1)"" == *"ARMResourceNotFoundFix"* ]]; then
    # Send message to stderr
    echo -e "Error: Source cluster \"$SOURCE_CLUSTER\" not found." >&2
    exit 0
fi

# Give option to create dest cluster if it does not exist
echo ""
echo "Verifying destination cluster existence..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$DEST_CLUSTER" 2>&1)"" == *"ARMResourceNotFoundFix"* ]]; then
    if [[ $USER_PROMPT == true ]]; then
        read -p "Destination cluster does not exists. Create cluster? (Y/n) " create_dest_cluster
        if [[ $create_dest_cluster =~ (N|n) ]]; then
            echo "Aborting..."
            exit 1
        fi
    fi

    # Copy spec of source cluster
    # NOTE: The normal spec of a cluster is determined by the (dev.env|prod.env in the AKS folder)
    NUM_NODES_IN_SOURCE_CLUSTER="$(kubectl get nodes --no-headers | wc -l | tr -d '[:space:]')"

    echo ""
    echo "Creating destination cluster..."
    (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$DEST_CLUSTER" USER_PROMPT="$USER_PROMPT" source "$BOOTSTRAP_AKS_SCRIPT")
    wait # wait for subshell to finish
    printf "Done creating cluster."

    [[ "$(kubectl config current-context)" != "$DEST_CLUSTER-admin" ]] && exit 1

    echo ""
    echo "Installing base components..."
    (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$DEST_CLUSTER" USER_PROMPT="$USER_PROMPT" source "$INSTALL_BASECOMPONENTS_SCRIPT")
    wait # wait for subshell to finish
    printf "Done installing base components."

fi

# Connect kubectl so we have the correct context
echo ""
printf "Point to destination cluster... "
az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$DEST_CLUSTER"
[[ "$(kubectl config current-context)" != "$DEST_CLUSTER-admin" ]] && exit 1

# Wait for operator to be deployed from flux
echo ""
echo "Waiting for radix-operator to be deployed by flux-operator so that it can handle migrated apps"
echo "If this lasts forever, are you migrating to a cluster without base components installed?"
while [[ "$(kubectl get deploy radix-operator 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done

# Wait for velero to be deployed from flux
echo ""
echo "Waiting for velero to be deployed by flux-operator so that it can handle restore into cluster from backup"
echo "If this lasts forever, are you migrating to a cluster without base components installed? (Tip: Try 'fluxctl sync' to force syncing flux repo)"
while [[ "$(kubectl get deploy velero -n velero 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done

echo ""
printf "Point to source cluster... "
az aks get-credentials --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$SOURCE_CLUSTER" \
    --overwrite-existing \
    --admin \
    2>&1 >/dev/null
[[ "$(kubectl config current-context)" != "$SOURCE_CLUSTER-admin" ]] && exit 1
printf "Done.\n"

echo ""
printf "Making backup of source cluster... "

cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  labels:
    velero.io/storage-location: azure
  name: $BACKUP_NAME
  namespace: velero
spec:
  excludedNamespaces:
  - velero
  - kube-system
  excludedResources:
  - pv
  - pvc
  hooks:
    resources: null
  includeClusterResources: true
  includedNamespaces:
  - '*'
  includedResources:
  - '*'
  labelSelector:
    matchExpressions:
    - key: release
      operator: NotIn
      values:
      - prometheus-operator
  storageLocation: azure
  ttl: 168h0m0s
  volumeSnapshotLocations:
  - azure
EOF

echo ""
printf "Restore into destination cluster... "
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" SOURCE_CLUSTER="$SOURCE_CLUSTER" DEST_CLUSTER="$DEST_CLUSTER" BACKUP_NAME="$BACKUP_NAME" USER_PROMPT="$USER_PROMPT" source "$RESTORE_APPS_SCRIPT")
wait # wait for subshell to finish
printf "Done restoring into cluster."

echo ""
read -p "Move custom ingresses (e.g. console.*.radix.equinor.com) from source to dest cluster? (Y/n) " -n 1 -r
if [[ "$REPLY" =~ (N|n) ]]; then
    echo ""
    echo "Chicken!"

    echo ""
    echo "For the web console to work we need to apply the secrets for the auth proxy, using the custom ingress as reply url"

    AUTH_PROXY_COMPONENT="auth"
    AUTH_PROXY_REPLY_PATH="/oauth2/callback"
    RADIX_WEB_CONSOLE_ENV="prod"
    if [[ $CLUSTER_TYPE  == "development" ]]; then
      echo "Development cluster uses QA web-console"
      RADIX_WEB_CONSOLE_ENV="qa"
    fi
    WEB_CONSOLE_NAMESPACE="radix-web-console-$RADIX_WEB_CONSOLE_ENV"

    (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" AUTH_PROXY_COMPONENT="$AUTH_PROXY_COMPONENT" WEB_CONSOLE_NAMESPACE="$WEB_CONSOLE_NAMESPACE" AUTH_PROXY_REPLY_PATH="$AUTH_PROXY_REPLY_PATH" ./update_auth_proxy_secret_for_console.sh)
    wait # wait for subshell to finish

    echo "Restarting web console to use updated secret value."
    $(kubectl delete pods --all -n radix-web-console-prod 2>&1 >/dev/null)

    exit 1
fi

echo ""
printf "Enabling monitoring addon in the destination cluster... "
WORKSPACE_ID=$(az resource list --resource-type Microsoft.OperationalInsights/workspaces --name radix-container-logs-$RADIX_ZONE | jq -r .[0].id)
az aks enable-addons -a monitoring -n $DEST_CLUSTER -g clusters --workspace-resource-id "$WORKSPACE_ID"
printf "Done.\n"

echo ""
printf "Disabling monitoring addon in the source cluster... "
az aks disable-addons -a monitoring -n $SOURCE_CLUSTER -g clusters
printf "Done.\n"

echo ""
printf "Point to source cluster... "
az aks get-credentials --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$SOURCE_CLUSTER" \
    --overwrite-existing \
    --admin \
    2>&1 >/dev/null
[[ "$(kubectl config current-context)" != "$SOURCE_CLUSTER-admin" ]] && exit 1
printf "Done.\n"

echo ""
printf "Delete custom ingresses... "
while read -r line; do
    if [[ "$line" ]]; then
        helm delete ${line}
    fi
done <<<"$(helm list --short | grep radix-ingress)"

# Point granana to cluster specific ingress
GRAFANA_ROOT_URL="https://grafana.$SOURCE_CLUSTER.$AZ_RESOURCE_DNS"
kubectl set env deployment/grafana GF_SERVER_ROOT_URL="$GRAFANA_ROOT_URL"

echo ""
printf "Point to destination cluster... "
az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$DEST_CLUSTER"
[[ "$(kubectl config current-context)" != "$DEST_CLUSTER-admin" ]] && exit 1

echo ""
printf "Create aliases in destination cluster... "
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$DEST_CLUSTER" USER_PROMPT="$USER_PROMPT" source "$BOOTSTRAP_APP_ALIAS_SCRIPT")
wait # wait for subshell to finish
printf "Done creating aliases."

# Point granana to cluster type ingress
GRAFANA_ROOT_URL="https://grafana.$AZ_RESOURCE_DNS"
kubectl set env deployment/grafana GF_SERVER_ROOT_URL="$GRAFANA_ROOT_URL"

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