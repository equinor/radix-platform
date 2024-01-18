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

hash cilium 2>/dev/null || {
    echo -e "\nERROR: cilium not found in PATH. Exiting..." >&2
    exit 1
}

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.46.0"
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

hash uuidgen 2>/dev/null || {
    echo -e "\nERROR: uuidgen not found in PATH. Exiting..." >&2
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

UPDATE_STORAGEACCOUNT_FIREWALL_SCRIPT="$WORKDIR_PATH/velero/update_storageaccount_firewall.sh"
if ! [[ -x "$UPDATE_STORAGEACCOUNT_FIREWALL_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The update storageaccount firewall script is not found or it is not executable in path $UPDATE_STORAGEACCOUNT_FIREWALL_SCRIPT" >&2
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

WEB_CONSOLE_CLUSTER_OIDC_ISSUER_SCRIPT="$WORKDIR_PATH/update_cluster_oidc_issuer_env_vars_for_console.sh"
if ! [[ -x "$WEB_CONSOLE_CLUSTER_OIDC_ISSUER_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The web console cluster oidc issuer script is not found or it is not executable in path $WEB_CONSOLE_CLUSTER_OIDC_ISSUER_SCRIPT" >&2
fi

# MOVE_CUSTOM_INGRESSES_SCRIPT="$WORKDIR_PATH/move_custom_ingresses.sh"
# if ! [[ -x "$MOVE_CUSTOM_INGRESSES_SCRIPT" ]]; then
#     # Print to stderror
#     echo "ERROR: The move custom ingresses script is not found or it is not executable in path $MOVE_CUSTOM_INGRESSES_SCRIPT" >&2
# fi

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

RADIX_LOG_API_ENV_VAR_AND_SECRET_SCRIPT="$WORKDIR_PATH/update_env_vars_and_secrets_for_radix_log_api.sh"
if ! [[ -x "$RADIX_LOG_API_ENV_VAR_AND_SECRET_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The Radix Log API env-var and secret script is not found or it is not executable in path $RADIX_LOG_API_ENV_VAR_AND_SECRET_SCRIPT" >&2
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

GITHUB_MAINTENANCE_SCRIPT="$WORKDIR_PATH/github_maintenance/bootstrap.sh"
if ! [[ -x "$GITHUB_MAINTENANCE_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The github maintenance secrets script is not found or it is not executable in path $GITHUB_MAINTENANCE_SCRIPT" >&2
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

echo ""
# Add grafana replyUrl to AAD app
printf "%s► Execute %s%s\n" "${grn}" "$ADD_REPLY_URL_SCRIPT" "${normal}"
(AAD_APP_NAME="${APP_REGISTRATION_GRAFANA}" K8S_NAMESPACE="monitor" K8S_INGRESS_NAME="grafana" REPLY_PATH="/login/generic_oauth" USER_PROMPT="$USER_PROMPT" source "$ADD_REPLY_URL_SCRIPT")
wait # wait for subshell to finish

# echo ""
# echo "Updating storageaccount firewall..."
# printf "%s► Execute %s%s\n" "${grn}" "$UPDATE_STORAGEACCOUNT_FIREWALL_SCRIPT" "${normal}"
# (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$DEST_CLUSTER" ACTION="add" source "$UPDATE_STORAGEACCOUNT_FIREWALL_SCRIPT")
# wait # wait for subshell to finish

#######################################################################################
### Verify cluster access
###
verify_cluster_access



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
(AAD_APP_NAME="Omnia Radix Web Console - ${CLUSTER_TYPE^}" K8S_NAMESPACE="$WEB_CONSOLE_NAMESPACE" K8S_INGRESS_NAME="$AUTH_PROXY_COMPONENT" REPLY_PATH="$AUTH_PROXY_REPLY_PATH" WEB_REDIRECT_URI="${WEB_REDIRECT_URI}" USER_PROMPT="$USER_PROMPT" source "$ADD_REPLY_URL_SCRIPT")
wait # wait for subshell to finish
printf "Done.\n"

# Update web console web component with list of all IPs assigned to the cluster type (development|playground|production)
echo ""
printf "%s► Execute %s%s\n" "${grn}" "$WEB_CONSOLE_EGRESS_IP_SCRIPT" "${normal}"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" WEB_COMPONENT="$WEB_COMPONENT" RADIX_WEB_CONSOLE_ENV="$RADIX_WEB_CONSOLE_ENV" CLUSTER_NAME="$DEST_CLUSTER" STAGING="$STAGING" source "$WEB_CONSOLE_EGRESS_IP_SCRIPT")
wait # wait for subshell to finish
echo ""

# Update web console web component with cluster oidc issuer url
echo ""
printf "%s► Execute %s%s\n" "${grn}" "$WEB_CONSOLE_CLUSTER_OIDC_ISSUER_SCRIPT" "${normal}"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$DEST_CLUSTER" STAGING="$STAGING" source "$WEB_CONSOLE_CLUSTER_OIDC_ISSUER_SCRIPT")
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
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER_NAME="$DEST_CLUSTER" STAGING="$STAGING" source "$UPDATE_NETWORKPOLICY_CANARY_SECRET_SCRIPT")
wait # wait for subshell to finish
echo ""



