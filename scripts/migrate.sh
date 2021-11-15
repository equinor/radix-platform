#!/usr/bin/env bash

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

INSTALL_BASE_COMPONENTS_SCRIPT="$WORKDIR_PATH/install_base_components.sh"
if ! [[ -x "$INSTALL_BASE_COMPONENTS_SCRIPT" ]]; then
    # Print to stderror
    echo "The install base components script is not found or it is not executable in path $INSTALL_BASE_COMPONENTS_SCRIPT" >&2
fi

CERT_MANAGER_CONFIGURATION_SCRIPT="$WORKDIR_PATH/cert-manager/configure.sh"
if ! [[ -x "$CERT_MANAGER_CONFIGURATION_SCRIPT" ]]; then
    # Print to stderror
    echo "The cert-manager configuration script is not found or it is not executable in path $CERT_MANAGER_CONFIGURATION_SCRIPT" >&2
fi

PROMETHEUS_CONFIGURATION_SCRIPT="$WORKDIR_PATH/prometheus-operator/configure.sh"
if ! [[ -x "$PROMETHEUS_CONFIGURATION_SCRIPT" ]]; then
    # Print to stderror
    echo "The prometheus configuration script is not found or it is not executable in path $PROMETHEUS_CONFIGURATION_SCRIPT" >&2
fi

DYNATRACE_INTEGRATION_SCRIPT="$WORKDIR_PATH/dynatrace/integration.sh"
if ! [[ -x "$DYNATRACE_INTEGRATION_SCRIPT" ]]; then
    # Print to stderror
    echo "The dynatrace integration script is not found or it is not executable in path $DYNATRACE_INTEGRATION_SCRIPT" >&2
fi

RESTORE_APPS_SCRIPT="$WORKDIR_PATH/velero/restore/restore_apps.sh"
if ! [[ -x "$RESTORE_APPS_SCRIPT" ]]; then
    # Print to stderror
    echo "The restore apps script is not found or it is not executable in path $RESTORE_APPS_SCRIPT" >&2
fi

#######################################################################################
### Check the migration strategy
###

while true; do
    read -p "Are you migrating active to active or active to test? (aa/at) " yn
    case $yn in
        "aa" ) MIGRATION_STRATEGY="aa"; break;;
        "at" ) MIGRATION_STRATEGY="at"; break;;
        * ) echo "Please answer aa or at.";;
    esac
done

echo ""

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
    while true; do
        read -p "Is this correct? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
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
        while true; do
            read -p "Destination cluster does not exists. Create cluster? (Y/n) " yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) echo "Aborting..."; exit 0;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

    # Copy spec of source cluster
    # NOTE: The normal spec of a cluster is determined by the (dev.env|prod.env in the AKS folder)
    NUM_NODES_IN_SOURCE_CLUSTER="$(kubectl get nodes --no-headers | wc -l | tr -d '[:space:]')"

    echo ""
    echo "Creating destination cluster..."
    (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$DEST_CLUSTER" USER_PROMPT="$USER_PROMPT" MIGRATION_STRATEGY="$MIGRATION_STRATEGY" source "$BOOTSTRAP_AKS_SCRIPT")
    wait # wait for subshell to finish
    printf "Done creating cluster."

    [[ "$(kubectl config current-context)" != "$DEST_CLUSTER-admin" ]] && exit 1
fi

install_base_components=true

if [[ $USER_PROMPT == true ]]; then
    echo ""
    while true; do
        read -p "Install base components? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) install_base_components=false; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ $install_base_components == true ]]; then
    echo ""
    echo "Installing base components..."
    (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$DEST_CLUSTER" USER_PROMPT="$USER_PROMPT" source "$INSTALL_BASE_COMPONENTS_SCRIPT")
    wait # wait for subshell to finish
    printf "Done installing base components."
fi

# Connect kubectl so we have the correct context
echo ""
printf "Point to destination cluster... "
az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$DEST_CLUSTER"
[[ "$(kubectl config current-context)" != "$DEST_CLUSTER-admin" ]] && exit 1


# Wait for cert-manager to be deployed from flux
# Verify installation (v1.3.1): https://cert-manager.io/v1.3-docs/installation/kubernetes/#verifying-the-installation
echo "Wait for cert-manager to be deployed by flux-operator..."
echo "If this lasts forever, are you migrating to a cluster without base components installed?"
while [[ "$(kubectl get deploy cert-manager -n cert-manager 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done
while [[ "$(kubectl get pods -n cert-manager -ojsonpath={.items[*].status.containerStatuses[*].ready} | grep --invert-match true 2>&1)" != "" ]]; do
    printf "."
    sleep 5s
done
echo ""
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" USER_PROMPT="$USER_PROMPT" CLUSTER_NAME="$DEST_CLUSTER" source "$CERT_MANAGER_CONFIGURATION_SCRIPT")
wait

# Wait for prometheus to be deployed from flux
echo "Wait for prometheus to be deployed by flux-operator..."
while [[ "$(kubectl get deploy prometheus-operator-operator 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done

echo ""
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" USER_PROMPT="$USER_PROMPT" CLUSTER_NAME="$DEST_CLUSTER" source "$PROMETHEUS_CONFIGURATION_SCRIPT")
wait

# Wait for operator to be deployed from flux
echo ""
echo "Waiting for radix-operator to be deployed by flux-operator so that it can handle migrated apps"
echo "If this lasts forever, are you migrating to a cluster without base components installed?"
while [[ "$(kubectl get deploy radix-operator 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done


# Wait for grafana to be deployed from flux
echo ""
echo "Waiting for grafana to be deployed by flux-operator so that we can add the ingress as a replyURL to \"$APP_REGISTRATION_GRAFANA\""
while [[ "$(kubectl get deploy grafana 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done
echo ""
# Add grafana replyUrl to AAD app
(AAD_APP_NAME="${APP_REGISTRATION_GRAFANA}" K8S_NAMESPACE="default" K8S_INGRESS_NAME="grafana" REPLY_PATH="/login/generic_oauth" USER_PROMPT="$USER_PROMPT" ./add_reply_url_for_cluster.sh)
wait # wait for subshell to finish


# Wait for dynatrace to be deployed from flux
echo ""
echo "Waiting for dynatrace to be deployed by flux-operator so that it can be integrated"
echo "If this lasts forever, are you migrating to a cluster without base components installed?"
while [[ "$(kubectl get deploy dynatrace-operator -n dynatrace 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done
echo ""
printf "Update Dynatrace integration... "
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" USER_PROMPT="$USER_PROMPT" CLUSTER_NAME="$DEST_CLUSTER" source "$DYNATRACE_INTEGRATION_SCRIPT")
wait # wait for subshell to finish
printf "Done updating Dynatrace integration."

# Wait for velero to be deployed from flux
echo ""
echo "Waiting for velero to be deployed by flux-operator so that it can handle restore into cluster from backup"
echo "If this lasts forever, are you migrating to a cluster without base components installed? (Tip: Allow 5 minutes. Try 'fluxctl sync' to force syncing flux repo)"
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

RADIX_WEB_CONSOLE_ENV="prod"
if [[ $CLUSTER_TYPE  == "development" ]]; then
    # Development cluster uses QA web-console
    RADIX_WEB_CONSOLE_ENV="qa"
fi
WEB_CONSOLE_NAMESPACE="radix-web-console-$RADIX_WEB_CONSOLE_ENV"

WEB_COMPONENT="web"

(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" WEB_COMPONENT="$WEB_COMPONENT" WEB_CONSOLE_NAMESPACE="$WEB_CONSOLE_NAMESPACE" ./update_egress_ips_web_secret_for_console.sh)

echo ""
while true; do
    read -p "Move custom ingresses (e.g. console.*.radix.equinor.com) from source to dest cluster? (Y/n) " yn
    case $yn in
        [Yy]* ) source move_custom_ingresses.sh; break;;
        [Nn]* ) 
            echo ""
            echo "Chicken!"

            echo ""
            echo "For the web console to work we need to apply the secrets for the auth proxy, using the custom ingress as reply url"

            AUTH_PROXY_COMPONENT="auth"
            AUTH_PROXY_REPLY_PATH="/oauth2/callback"

            (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" AUTH_PROXY_COMPONENT="$AUTH_PROXY_COMPONENT" WEB_CONSOLE_NAMESPACE="$WEB_CONSOLE_NAMESPACE" AUTH_PROXY_REPLY_PATH="$AUTH_PROXY_REPLY_PATH" ./update_auth_proxy_secret_for_console.sh)
            wait # wait for subshell to finish
            break;;
        * ) echo "Please answer yes or no.";;
    esac
done