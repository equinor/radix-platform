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

# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env SOURCE_CLUSTER=beastmode-11 DEST_CLUSTER=mommas-boy-12 ./migrate.sh > >(tee -a /tmp/stdout.log) 2> >(tee -a /tmp/stderr.log >&2)

# or without log:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env SOURCE_CLUSTER=weekly-01 DEST_CLUSTER=weekly-02 ./migrate.sh

# DISASTER RECOVERY:
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env SOURCE_CLUSTER=weekly-19 BACKUP_NAME=all-hourly-20220510150047 DEST_CLUSTER=weekly-19c ./migrate.sh

#######################################################################################
### Check for prerequisites binaries
###

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.41.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI.${normal}\n"
    exit 1
fi

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}

hash envsubst 2>/dev/null || {
    echo -e "\nERROR: envsubst not found in PATH. Exiting..." >&2
    exit 1
}

hash helm 2>/dev/null || {
    echo -e "\nERROR: helm not found in PATH. Exiting..." >&2
    exit 1
}

hash velero 2>/dev/null || {
    echo -e "\nERROR: velero not found in PATH. Exiting..." >&2
    exit 1
}

hash htpasswd 2>/dev/null || {
    echo -e "\nERROR: htpasswd not found in PATH. Exiting..." >&2
    exit 1
}

hash flux 2>/dev/null || {
    echo -e "\nERROR: flux not found in PATH. Exiting... " >&2
    exit 1
}

hash sqlcmd 2>/dev/null || {
    echo -e "\nERROR: sqlcmd not found in PATH. Exiting... " >&2
    exit 1
}

hash kubelogin 2>/dev/null || {
    echo -e "\nERROR: kubelogin not found in PATH. Exiting... " >&2
    exit 1
}

printf "Done.\n"

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

if [[ -z "$SOURCE_CLUSTER" ]]; then
    echo "ERROR: Please provide SOURCE_CLUSTER" >&2
    exit 1
fi

if [[ -z "$DEST_CLUSTER" ]]; then
    echo "ERROR: Please provide DEST_CLUSTER" >&2
    exit 1
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

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
RADIX_ZONE_PATH="${WORKDIR_PATH}/radix-zone"

BOOTSTRAP_AKS_SCRIPT="$WORKDIR_PATH/aks/bootstrap.sh"
if ! [[ -x "$BOOTSTRAP_AKS_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The bootstrap script is not found or it is not executable in path $BOOTSTRAP_AKS_SCRIPT" >&2
fi

INSTALL_BASE_COMPONENTS_SCRIPT="$WORKDIR_PATH/install_base_components.sh"
if ! [[ -x "$INSTALL_BASE_COMPONENTS_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The install base components script is not found or it is not executable in path $INSTALL_BASE_COMPONENTS_SCRIPT" >&2
fi

PROMETHEUS_CONFIGURATION_SCRIPT="$WORKDIR_PATH/prometheus-operator/configure.sh"
if ! [[ -x "$PROMETHEUS_CONFIGURATION_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The prometheus configuration script is not found or it is not executable in path $PROMETHEUS_CONFIGURATION_SCRIPT" >&2
fi

RESTORE_APPS_SCRIPT="$WORKDIR_PATH/velero/restore/restore_apps.sh"
if ! [[ -x "$RESTORE_APPS_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The restore apps script is not found or it is not executable in path $RESTORE_APPS_SCRIPT" >&2
fi

ADD_REPLY_URL_SCRIPT="$WORKDIR_PATH/add_reply_url_for_cluster.sh"
if ! [[ -x "$ADD_REPLY_URL_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The replyUrl script is not found or it is not executable in path $ADD_REPLY_URL_SCRIPT" >&2
fi

WEB_CONSOLE_EGRESS_IP_SCRIPT="$WORKDIR_PATH/update_ips_env_vars_for_console.sh"
if ! [[ -x "$WEB_CONSOLE_EGRESS_IP_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The web console egress ip script is not found or it is not executable in path $WEB_CONSOLE_EGRESS_IP_SCRIPT" >&2
fi

MOVE_CUSTOM_INGRESSES_SCRIPT="$WORKDIR_PATH/move_custom_ingresses.sh"
if ! [[ -x "$MOVE_CUSTOM_INGRESSES_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The move custom ingresses script is not found or it is not executable in path $MOVE_CUSTOM_INGRESSES_SCRIPT" >&2
fi

UPDATE_AUTH_PROXY_SECRET_SCRIPT="$WORKDIR_PATH/update_auth_proxy_secret_for_console.sh"
if ! [[ -x "$UPDATE_AUTH_PROXY_SECRET_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The update auth proxy secret script is not found or it is not executable in path $UPDATE_AUTH_PROXY_SECRET_SCRIPT" >&2
fi

UPDATE_NETWORKPOLICY_CANARY_SECRET_SCRIPT="$WORKDIR_PATH/cicd-canary/update_secret_for_networkpolicy_canary.sh"
if ! [[ -x "$UPDATE_NETWORKPOLICY_CANARY_SECRET_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The update networkpolicy canary secret script is not found or it is not executable in path $UPDATE_NETWORKPOLICY_CANARY_SECRET_SCRIPT" >&2
fi

CREATE_REDIS_CACHE_SCRIPT="$WORKDIR_PATH/redis/create_redis_cache_for_console.sh"
if ! [[ -x "$CREATE_REDIS_CACHE_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The create redis cache script is not found or it is not executable in path $CREATE_REDIS_CACHE_SCRIPT" >&2
fi

UPDATE_REDIS_CACHE_SECRET_SCRIPT="$WORKDIR_PATH/redis/update_redis_cache_for_console.sh"
if ! [[ -x "$UPDATE_REDIS_CACHE_SECRET_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The update redis cache script is not found or it is not executable in path $UPDATE_REDIS_CACHE_SECRET_SCRIPT" >&2
fi

RADIX_API_ENV_VAR_SCRIPT="$WORKDIR_PATH/update_env_vars_for_radix_api.sh"
if ! [[ -x "$RADIX_API_ENV_VAR_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The Radix API env-var script is not found or it is not executable in path $RADIX_API_ENV_VAR_SCRIPT" >&2
fi

CHECK_KEYVAULT_SECRETS="$WORKDIR_PATH/check_keyvault_secrets.sh"
if ! [[ -x "$CHECK_KEYVAULT_SECRETS" ]]; then
    # Print to stderror
    echo "ERROR: The check keyvault secrets script is not found or it is not executable in path $CHECK_KEYVAULT_SECRETS" >&2
fi

CHECK_APPREG_SECRETS="$WORKDIR_PATH/check_appreg_secrets.sh"
if ! [[ -x "$CHECK_APPREG_SECRETS" ]]; then
    # Print to stderror
    echo "ERROR: The check keyvault secrets script is not found or it is not executable in path $CHECK_APPREG_SECRETS" >&2
fi

CREATE_A_RECORDS_SCRIPT="$WORKDIR_PATH/external-dns-prerequisites/create_a_records.sh"
if ! [[ -x "$CREATE_A_RECORDS_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The create A records script is not found or it is not executable in path $CREATE_A_RECORDS_SCRIPT" >&2
fi

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"


#######################################################################################
### Verifying owner on scope of subscription is activated
###

printf "Verifying that logged in AAD user has Owner on scope of ${AZ_SUBSCRIPTION_ID} subscription... "
az role assignment list --scope /subscriptions/${AZ_SUBSCRIPTION_ID} --assignee "$(az ad signed-in-user show --query id -o tsv)" --query [].roleDefinitionName -o tsv | grep -E "^Owner\$"
if [[ "$?" != "0" ]]; then
  echo -e "ERROR: Logged in user is not Owner on scope of ${AZ_SUBSCRIPTION_ID} subscription. Is PIM assignment activated?" >&2
  exit 1
fi
printf "Done.\n"

#######################################################################################
### Check the migration strategy
###

while true; do
    read -r -e -p "Are you migrating active to active or active to test? (aa/at) " -i "at" yn
    case $yn in
    "aa")
        MIGRATION_STRATEGY="aa"
        break
        ;;
    "at")
        MIGRATION_STRATEGY="at"
        break
        ;;
    *) echo "Please answer aa or at." ;;
    esac
done

echo ""

#######################################################################################
### Staging certs on test cluster
###

STAGING=false
if [[ ${MIGRATION_STRATEGY} == "at" ]]; then
    while true; do
        read -r -e -p "Do you want to use Staging certs on $DEST_CLUSTER? " -i "y" yn
        case $yn in
        [Yy]*)
            check_staging_certs 
            STAGING=true
            break ;;
        [Nn]*)  break ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
fi
echo ""

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
echo -e "   -  BACKUP_NAME                      : $BACKUP_NAME"
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
        [Yy]*) break ;;
        [Nn]*)
            echo ""
            echo "Quitting."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
fi

#--------------------------------------------------------

#######################################################################################
### Connect kubectl
###

if [[ ${BACKUP_NAME} == "migration-"* ]]; then
    # Exit if source cluster does not exist
    echo ""
    echo "Verifying source cluster existence..."
    get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$SOURCE_CLUSTER" || {
        echo -e "ERROR: Source cluster \"$SOURCE_CLUSTER\" not found." >&2
        exit 1
    }
    echo ""
fi

create_redis_cache=true
if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -r -p "Create Redis Caches for Console? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            create_redis_cache=false
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    echo ""
fi

if [[ $create_redis_cache == true ]]; then
    printf "Creating Redis Caches for Console...\n"
    (
        printf "%s► Execute %s (RADIX_WEB_CONSOLE_ENV=qa)%s\n" "${grn}" "$CREATE_REDIS_CACHE_SCRIPT" "${normal}"
        RADIX_ZONE_ENV="$RADIX_ZONE_ENV" AUTH_PROXY_COMPONENT="$AUTH_PROXY_COMPONENT" CLUSTER_NAME="$DEST_CLUSTER" RADIX_WEB_CONSOLE_ENV="qa" USER_PROMPT="false" source "$CREATE_REDIS_CACHE_SCRIPT"
        echo ""
        printf "%s► Execute %s (RADIX_WEB_CONSOLE_ENV=prod)%s\n" "${grn}" "$CREATE_REDIS_CACHE_SCRIPT" "${normal}"
        RADIX_ZONE_ENV="$RADIX_ZONE_ENV" AUTH_PROXY_COMPONENT="$AUTH_PROXY_COMPONENT" CLUSTER_NAME="$DEST_CLUSTER" RADIX_WEB_CONSOLE_ENV="prod" USER_PROMPT="false" source "$CREATE_REDIS_CACHE_SCRIPT"
    )
    printf "Done...\n"
fi

# Give option to create dest cluster if it does not exist
echo ""
echo "Verifying destination cluster existence..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$DEST_CLUSTER" || {
    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -r -p "Destination cluster does not exists. Create cluster? (Y/n) " yn
            case $yn in
            [Yy]*) break ;;
            [Nn]*)
                echo "Aborting..."
                exit 0
                ;;
            *) echo "Please answer yes or no." ;;
            esac
        done
    fi

    echo ""
    echo "Creating destination cluster..."
    printf "%s► Execute %s%s\n" "${grn}" "$BOOTSTRAP_AKS_SCRIPT" "${normal}"
    (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$DEST_CLUSTER" USER_PROMPT="$USER_PROMPT" MIGRATION_STRATEGY="$MIGRATION_STRATEGY" source "$BOOTSTRAP_AKS_SCRIPT")
    wait # wait for subshell to finish

    [[ "$(kubectl config current-context)" != "$DEST_CLUSTER" ]] && exit 1
}
printf "Done creating cluster.\n"
install_base_components=true

if [[ $USER_PROMPT == true ]]; then
    echo ""
    while true; do
        read -r -p "Install base components? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            install_base_components=false
            break
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
fi

if [[ $install_base_components == true ]]; then
    echo ""
    echo "Installing base components..."
    printf "%s► Execute %s%s\n" "${grn}" "${INSTALL_BASE_COMPONENTS_SCRIPT}" "${normal}"
    (RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" CLUSTER_NAME="${DEST_CLUSTER}" MIGRATION_STRATEGY="${MIGRATION_STRATEGY}" USER_PROMPT="${USER_PROMPT}" STAGING="${STAGING}" source "${INSTALL_BASE_COMPONENTS_SCRIPT}")
    wait # wait for subshell to finish
fi

# Connect kubectl so we have the correct context
echo ""
printf "Point to destination cluster... "
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$DEST_CLUSTER"
[[ "$(kubectl config current-context)" != "$DEST_CLUSTER" ]] && exit 1

if [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    package="tmux"
    checkpackage=$(dpkg -s ${package} /dev/null 2>&1 | grep Status:)
    if [[ -n ${checkpackage} ]]; then
        tmux new -s flux -d 'watch "kubectl get ks -A"' \; split-window -v 'watch "kubectl get hr -A"'
        echo "Please open a new terminal window, and run following command:"
        echo ""
        echo "tmux a -t flux"
        echo ""
        echo "Hit space after every kustomizations and helmreleases is in 'Ready' state."
        echo "(Tip: You migt need to open another terminal windows to do flux reconcile commands etc...)"
        read -r -s -d ' '
        tmux kill-session -t flux
    else
        echo "Optional: Please do 'sudo apt install ${package}' for instruction how to monitor Flux kustomizations and helmreleases before you run the migration script next time......"
        echo "You can run it manually now in seperate terminal windows:"
        echo "watch \"kubectl get ks -A\""
        echo "watch \"kubectl get hr -A\""
    fi

fi

# Wait for prometheus to be deployed from flux
echo ""
printf "Wait for prometheus to be deployed by flux-operator..."
while [[ "$(kubectl get deploy prometheus-operator-operator 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5
done
printf " Done.\n"

echo ""
printf "%s► Execute %s%s\n" "${grn}" "$PROMETHEUS_CONFIGURATION_SCRIPT" "${normal}"
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" USER_PROMPT="${USER_PROMPT}" CLUSTER_NAME="${DEST_CLUSTER}" source "${PROMETHEUS_CONFIGURATION_SCRIPT}")
wait

# Wait for operator to be deployed from flux
echo ""
echo "Waiting for radix-operator to be deployed by flux-operator so that it can handle migrated apps"
echo "If this lasts forever, are you migrating to a cluster without base components installed?"
while [[ "$(kubectl get deploy radix-operator 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5
done
printf " Done."

# Wait for grafana to be deployed from flux
echo ""
echo "Waiting for grafana to be deployed by flux-operator so that we can add the ingress as a replyURL to \"$APP_REGISTRATION_GRAFANA\""
while [[ "$(kubectl get deploy grafana 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5
done

echo ""
# Add grafana replyUrl to AAD app
printf "%s► Execute %s%s\n" "${grn}" "$ADD_REPLY_URL_SCRIPT" "${normal}"
(AAD_APP_NAME="${APP_REGISTRATION_GRAFANA}" K8S_NAMESPACE="default" K8S_INGRESS_NAME="grafana" REPLY_PATH="/login/generic_oauth" USER_PROMPT="$USER_PROMPT" source "$ADD_REPLY_URL_SCRIPT")
wait # wait for subshell to finish

# Wait for velero to be deployed from flux
echo ""
echo "Waiting for velero to be deployed by flux-operator so that it can handle restore into cluster from backup"
echo "If this lasts forever, are you migrating to a cluster without base components installed? (Tip: Allow 5 minutes. Try 'fluxctl sync' to force syncing flux repo)"
while [[ "$(kubectl get deploy velero --namespace velero 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5
done

echo ""
printf "Point to source cluster... "
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$SOURCE_CLUSTER" >/dev/null

#######################################################################################
### Verify cluster access
###
verify_cluster_access

[[ "$(kubectl config current-context)" != "$SOURCE_CLUSTER" ]] && exit 1
printf "Done.\n"

echo ""

printf "Making sure Velero backupstoragelocation are set for $SOURCE_CLUSTER... "
kubectl patch backupstoragelocation azure --namespace velero --type merge --patch '{"spec": {"objectStorage": {"bucket": "'${SOURCE_CLUSTER}'"}}}'

printf "Making backup of source cluster... "
cat <<EOF | kubectl apply --filename -
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

if [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    package="tmux"
    checkpackage=$(dpkg -s ${package} /dev/null 2>&1 | grep Status:)
    if [[ -n ${checkpackage} ]]; then
        tmux new -s velero -d 'watch "kubectl get restores.velero.io -n velero -o custom-columns=name:.metadata.name,status:.status.phase,restored:.status.progress.itemsRestored,total:.status.progress.totalItems"'
        echo "Please open a new terminal window, and run following command:"
        echo ""
        echo "tmux a -t velero"
        echo ""
        KILL_VELERO_WINDOWS=true
    else
        echo "Optional: Please do 'sudo apt install ${package}' for instruction how to monitor Velero restore in the migration script next time......"
        echo "You can run it manually now:"
        echo "watch \"kubectl get restores.velero.io -n velero -o custom-columns=name:.metadata.name,status:.status.phase,restored:.status.progress.itemsRestored,total:.status.progress.totalItems\""
    fi

fi

if [[ $USER_PROMPT == true ]]; then
    echo ""
    echo "About to restore into destination cluster."
    while true; do
        read -r -p "Do you want to be notified once restoration has been completed? (Y/n) " yn
        case $yn in
        [Yy]*)
            ENABLE_NOTIFY=true
            break
            ;;
        [Nn]*)
            ENABLE_NOTIFY=false
            break
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
fi

if [[ $ENABLE_NOTIFY == true ]]; then
    while true; do
        read -r -p "Enter slack @ username(s). Example: \"@olmt, @ssmol, @omnia-radix\": " slack_users
        read -r -p "You have selected \"$slack_users\". Is this correct? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*) echo "" ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
fi

echo ""
printf "Restore into destination cluster...\n"
printf "%s► Execute %s%s\n" "${grn}" "$RESTORE_APPS_SCRIPT" "${normal}"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" SOURCE_CLUSTER="$SOURCE_CLUSTER" DEST_CLUSTER="$DEST_CLUSTER" BACKUP_NAME="$BACKUP_NAME" USER_PROMPT="$USER_PROMPT" source "$RESTORE_APPS_SCRIPT")
wait # wait for subshell to finish
printf "Done restoring into cluster."

if [[ $KILL_VELERO_WINDOWS == true ]]; then
    tmux kill-session -t velero
fi

if [[ $ENABLE_NOTIFY == true ]]; then
    # Notify on slack
    echo "Notify on slack"
    # Get slack webhook url
    SLACK_WEBHOOK_URL="$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name "$KV_SECRET_SLACK_WEBHOOK" | jq -r .value)"
    curl -X POST -H 'Content-type: application/json' --data '{"text":"'"$slack_users"' Restore has been completed.","link_names":1}' "$SLACK_WEBHOOK_URL"
fi

# Define web console variables
RADIX_WEB_CONSOLE_ENV="prod"
if [[ $CLUSTER_TYPE == "development" ]]; then
    # Development cluster uses QA web-console
    RADIX_WEB_CONSOLE_ENV="qa"
fi
WEB_CONSOLE_NAMESPACE="radix-web-console-$RADIX_WEB_CONSOLE_ENV"
AUTH_PROXY_COMPONENT="auth"
AUTH_PROXY_REPLY_PATH="/oauth2/callback"
WEB_REDIRECT_URI="/applications"
WEB_COMPONENT="web"

# Update replyUrls for those radix apps that require AD authentication
printf "\nWaiting for web-console ingress to be ready so we can add replyUrl to web console aad app..."
while [[ "$(kubectl get ingress $AUTH_PROXY_COMPONENT --namespace $WEB_CONSOLE_NAMESPACE 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5
done
printf "\nIngress is ready, adding replyUrl for radix web-console...\n"

printf "%s► Execute %s%s\n" "${grn}" "$ADD_REPLY_URL_SCRIPT" "${normal}"
(AAD_APP_NAME="Omnia Radix Web Console - ${CLUSTER_TYPE^} Clusters" K8S_NAMESPACE="$WEB_CONSOLE_NAMESPACE" K8S_INGRESS_NAME="$AUTH_PROXY_COMPONENT" REPLY_PATH="$AUTH_PROXY_REPLY_PATH" WEB_REDIRECT_URI="${WEB_REDIRECT_URI}" USER_PROMPT="$USER_PROMPT" source "$ADD_REPLY_URL_SCRIPT")
wait # wait for subshell to finish
printf "Done.\n"

# Update web console web component with list of all IPs assigned to the cluster type (development|playground|production)
echo ""
printf "%s► Execute %s%s\n" "${grn}" "$WEB_CONSOLE_EGRESS_IP_SCRIPT" "${normal}"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" WEB_COMPONENT="$WEB_COMPONENT" RADIX_WEB_CONSOLE_ENV="$RADIX_WEB_CONSOLE_ENV" CLUSTER_NAME="$DEST_CLUSTER" source "$WEB_CONSOLE_EGRESS_IP_SCRIPT")
wait # wait for subshell to finish
echo ""

printf "Waiting for radix-networkpolicy-canary environments... "
while [[ ! $(kubectl get radixenvironments --output jsonpath='{.items[?(.metadata.labels.radix-app=="radix-networkpolicy-canary")].metadata.name}') ]]; do
    printf "."
    sleep 5
done
printf "Done.\n"

# Update networkpolicy canary with HTTP password to access endpoint for scheduling batch job
printf "\n%s► Execute %s%s\n" "${grn}" "$UPDATE_NETWORKPOLICY_CANARY_SECRET_SCRIPT" "${normal}"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$DEST_CLUSTER" source "$UPDATE_NETWORKPOLICY_CANARY_SECRET_SCRIPT")
wait # wait for subshell to finish
echo ""

update_redis_cache=true
if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -r -p "Update Redis Caches for Console? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            update_redis_cache=false
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
    echo ""
fi

# Wait for redis caches to be created.
printf "\nWaiting for redis caches to be created..."
while [[ $(az redis show --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$DEST_CLUSTER"-qa --query provisioningState -otsv 2>&1) != "Succeeded" && $(az redis show --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$DEST_CLUSTER"-prod --query provisioningState -otsv 2>&1) != "Succeeded" ]]; do
    printf "."
    sleep 5
done
printf " Done\n."

if [[ $update_redis_cache == true ]]; then
    printf "Updating Redis Caches for Console...\n"
    (
        printf "%s► Execute %s (RADIX_WEB_CONSOLE_ENV=qa)%s\n" "${grn}" "$UPDATE_REDIS_CACHE_SECRET_SCRIPT" "${normal}"
        RADIX_ZONE_ENV="$RADIX_ZONE_ENV" AUTH_PROXY_COMPONENT="$AUTH_PROXY_COMPONENT" CLUSTER_NAME="$DEST_CLUSTER" RADIX_WEB_CONSOLE_ENV="qa" USER_PROMPT="false" source "$UPDATE_REDIS_CACHE_SECRET_SCRIPT"
        printf "%s► Execute %s (RADIX_WEB_CONSOLE_ENV=prod)%s\n" "${grn}" "$UPDATE_REDIS_CACHE_SECRET_SCRIPT" "${normal}"
        RADIX_ZONE_ENV="$RADIX_ZONE_ENV" AUTH_PROXY_COMPONENT="$AUTH_PROXY_COMPONENT" CLUSTER_NAME="$DEST_CLUSTER" RADIX_WEB_CONSOLE_ENV="prod" USER_PROMPT="false" source "$UPDATE_REDIS_CACHE_SECRET_SCRIPT"
    )
    printf "Done...\n"
fi

# Create A records, both cluster specific and active-cluster record
printf "%s► Execute %s%s\n" "${grn}" "$CREATE_A_RECORDS_SCRIPT" "${normal}"
(RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" MIGRATION_STRATEGY="${MIGRATION_STRATEGY}" CLUSTER_NAME="${DEST_CLUSTER}" USER_PROMPT="${USER_PROMPT}" source "${CREATE_A_RECORDS_SCRIPT}")

# Move custom ingresses
if [[ $MIGRATION_STRATEGY == "aa" ]]; then
    CUSTOM_INGRESSES=true
else
    CUSTOM_INGRESSES=false
fi

echo ""
if [[ $USER_PROMPT == true && $MIGRATION_STRATEGY == "aa" ]]; then
    while true; do
        read -r -p "Move custom ingresses (e.g. console.*.radix.equinor.com) from source to dest cluster? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            CUSTOM_INGRESSES=false
            break
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
fi

if [[ $CUSTOM_INGRESSES == true ]]; then
    printf "%s► Execute %s (RADIX_WEB_CONSOLE_ENV=qa)%s\n" "${grn}" "$MOVE_CUSTOM_INGRESSES_SCRIPT" "${normal}"
    source "$MOVE_CUSTOM_INGRESSES_SCRIPT"
else
    echo ""
    printf "For the web console to work we need to apply the secrets for the auth proxy, using the custom ingress as reply url\n"
    printf "Update Auth proxy secret...\n"
    printf "%s► Execute %s%s\n" "${grn}" "$UPDATE_AUTH_PROXY_SECRET_SCRIPT" "${normal}"
    (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" AUTH_PROXY_COMPONENT="$AUTH_PROXY_COMPONENT" WEB_COMPONENT="$WEB_COMPONENT" WEB_CONSOLE_NAMESPACE="$WEB_CONSOLE_NAMESPACE" AUTH_PROXY_REPLY_PATH="$AUTH_PROXY_REPLY_PATH" source "$UPDATE_AUTH_PROXY_SECRET_SCRIPT")
    wait # wait for subshell to finish
fi

if [[ -d "${RADIX_ZONE_PATH}" ]]; then
    for filename in "${RADIX_ZONE_PATH}"/*.env; do
        if [[ "${filename}" == *classic* || "${filename}" == *test* ]]; then continue; fi
        radix_zone_env="${filename}"

        # Check keyvault secrets
        printf "%s► Execute %s%s\n" "${grn}" "$CHECK_KEYVAULT_SECRETS" "${normal}"
        (RADIX_ZONE_ENV=${radix_zone_env} USER_PROMPT="$USER_PROMPT" source "$CHECK_KEYVAULT_SECRETS")
        wait # wait for subshell to finish
        echo ""
    done
    unset radix_zone_env
else
    printf "ERROR: The radix-zone path is not found\n" >&2
fi

# Update Radix API env vars
echo ""
printf "%s► Execute %s%s\n" "${grn}" "$RADIX_API_ENV_VAR_SCRIPT" "${normal}"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$DEST_CLUSTER" source "$RADIX_API_ENV_VAR_SCRIPT")
wait # wait for subshell to finish
echo ""

# Check Appreg secrets
printf "%s► Execute %s%s\n" "${grn}" "$CHECK_APPREG_SECRETS" "${normal}"
(RADIX_ZONE_ENV=${RADIX_ZONE_ENV} USER_PROMPT="$USER_PROMPT" source "$CHECK_APPREG_SECRETS")
wait # wait for subshell to finish
echo ""

printf "\n"
printf "%sDone.%s\n" "${grn}" "${normal}"
