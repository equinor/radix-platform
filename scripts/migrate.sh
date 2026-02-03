#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Migrate the radix platform from cluster to cluster

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE          : dev|playground|prod|c2|c3
# - SOURCE_CLUSTER      : Ex: "test-2", "weekly-93"
# - DEST_CLUSTER        : Ex: "test-2", "weekly-93"

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###
# Migrate:
# RADIX_ZONE=dev SOURCE_CLUSTER=weekly-34 DEST_CLUSTER=cilium-35 ./migrate.sh > >(tee -a /tmp/stdout.log) 2> >(tee -a /tmp/stderr.log >&2)

# or without log:
# RADIX_ZONE=dev SOURCE_CLUSTER=weekly-34 DEST_CLUSTER=weekly-35 ./migrate.sh

# DISASTER RECOVERY:
# RADIX_ZONE=dev SOURCE_CLUSTER=weekly-19 BACKUP_NAME=all-hourly-20220510150047 DEST_CLUSTER=weekly-19c FLUX_BRANCH=mybranch ./migrate.sh

# Subfunction:
# RADIX_ZONE=dev SUBFUNCTION=flux DEST_CLUSTER=weekly-35 ./migrate.sh

#######################################################################################
### SUBFUNCTIONS:
###

# Available subfunctions:
# RADIX_ZONE=dev SUBFUNCTION=flux DEST_CLUSTER=weekly-35 ./migrate.sh


red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

# Required inputs

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2|c3)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2|c3" >&2
    exit 1
fi

RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh
check_installed_components

#######################################################################################
### Functions
###

function login_azure() {
  #######################################################################################
  ### Prepare az session
  ###
  echo ""
  AZ_SUBSCRIPTION_ID="$1"
  printf "Logging in to Azure Subscription ID: %s\n" "$1"
  az account show >/dev/null || az login >/dev/null
  az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
}
function flux_configmap() {
  # Create configmap for Flux v2 to use for variable substitution. (https://fluxcd.io/docs/components/kustomize/kustomization/#variable-substitution)
  get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$DEST_CLUSTER" >/dev/null
  printf "\n%s► Deploy radix-flux-config configmap in flux namespace\n"
  CM=$(kubectl create configmap radix-flux-config -n flux-system --dry-run=client -o yaml \
      --from-literal=dnsZone="$AZ_RESOURCE_DNS" \
      --from-literal=appAliasBaseURL="app.$AZ_RESOURCE_DNS" \
      --from-literal=prometheusName="radix-stage1" \
      --from-literal=imageRegistry="$IMAGE_REGISTRY" \
      --from-literal=pipGatewayIp="$(cat $(config_path $RADIX_ZONE) | yq .networksets.$(cat $(config_path $RADIX_ZONE) | yq .clusters.$DEST_CLUSTER.networkset).gatewayPIP)" \
      --from-literal=clusterName="$CLUSTER_NAME" \
      --from-literal=clusterType="$(yq '.cluster_type' <<< "$RADIX_ZONE_YAML")" \
      --from-literal=slackWebhookURL="$SLACK_WEBHOOK_URL" \
      --from-literal=subscriptionId="$AZ_SUBSCRIPTION_ID" \
      --from-literal=dnsZoneResourceGroup="$AZ_RESOURCE_GROUP_DNS" \
      --from-literal=radixIdCertManager="$RADIX_ID_CERTMANAGER_MI_CLIENT_ID" \
      --from-literal=zone="$RADIX_ENVIRONMENT" )
  echo ""
  printf "%s%s\n" "${grn}" "$CM" "${normal}"
  echo ""
  if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -r -p "Is this correct? (Y/n) " yn
        case $yn in
        [Yy]*) 
            kubectl replace --force -f - <<< "$CM"
            break
            ;;
        [Nn]*)
            echo ""
            echo "Quitting."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
fi
}

function check_secrets_exist() {
    local keyvault_name="$1"
    shift
    local keys=("$@")
    local missing_secrets=()
    
    for key in "${keys[@]}"; do
        if ! az keyvault secret show --vault-name "$keyvault_name" --name "$key" &>/dev/null; then
            missing_secrets+=("$key")
        fi
    done
    
    if [ ${#missing_secrets[@]} -gt 0 ]; then
        echo "ERROR: Missing secrets in Key Vault '$keyvault_name': ${missing_secrets[*]}" >&2
        return 1
    fi
    
    return 0
}


#######################################################################################
### Read Zone Config
###

if [[ -z "$DEST_CLUSTER" ]]; then
    echo "ERROR: Please provide DEST_CLUSTER" >&2
    exit 1
fi

if [[ -z "$SUBFUNCTION" ]]; then
  if [[ -z "$SOURCE_CLUSTER" ]]; then
    echo "ERROR: Please provide SOURCE_CLUSTER" >&2
    exit 1
fi

fi

if [[ -z "$FLUX_BRANCH" ]]; then
    FLUX_BRANCH="master"

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
RADIX_ZONE_PATH="${WORKDIR_PATH}/radix-zone"

BOOTSTRAP_AKS_SCRIPT="$WORKDIR_PATH/aks/bootstrap.sh"
if ! [[ -x "$BOOTSTRAP_AKS_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The bootstrap script is not found or it is not executable in path $BOOTSTRAP_AKS_SCRIPT" >&2
fi

RESTORE_APPS_SCRIPT="$WORKDIR_PATH/velero/restore/restore_apps.sh"
if ! [[ -x "$RESTORE_APPS_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The restore apps script is not found or it is not executable in path $RESTORE_APPS_SCRIPT" >&2
fi

UPDATE_NETWORKPOLICY_CANARY_SECRET_SCRIPT="$WORKDIR_PATH/cicd-canary/update_secret_for_networkpolicy_canary.sh"
if ! [[ -x "$UPDATE_NETWORKPOLICY_CANARY_SECRET_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The update networkpolicy canary secret script is not found or it is not executable in path $UPDATE_NETWORKPOLICY_CANARY_SECRET_SCRIPT" >&2
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
CLUSTER_NAME="$DEST_CLUSTER"
#######################################################################################
# YAML values (Input from static config.yaml from each zone)
AZ_RADIX_ZONE_LOCATION=$(yq '.location' <<< "$RADIX_ZONE_YAML")
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
AZ_SUBSCRIPTION_NAME=$(yq '.subscription_shortname' <<< "$RADIX_ZONE_YAML")
APP_CONFIG_NAME="radix-appconfig-$(yq '.environment' <<< "$RADIX_ZONE_YAML")"
RADIX_ENVIRONMENT=$(yq '.environment' <<< "$RADIX_ZONE_YAML")

# JSON values (Generated from function environment_json which reads from terraform outputs)
AZ_RESOURCE_DNS=$(jq -r .dnz_zone <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_GROUP_COMMON=$(jq -r .common_rg <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_GROUP_DNS=$(jq -r .dns_zone_resource_group <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_KEYVAULT=$(jq -r .keyvault <<< "$RADIX_RESOURCE_JSON")
IMAGE_REGISTRY=$(jq -r .acr <<< "$RADIX_RESOURCE_JSON")
MIGRATION_STRATEGY="aa"
STORAGACCOUNT=$(jq -r .velero_sa <<< "$RADIX_RESOURCE_JSON")
RADIX_ID_CERTMANAGER_MI_CLIENT_ID=$(jq -r .radix_id_certmanager_mi_client_id <<< "$RADIX_RESOURCE_JSON")
login_azure "$AZ_SUBSCRIPTION_ID"

# Key Vault values
SLACK_WEBHOOK_URL="$(az keyvault secret show --vault-name $AZ_RESOURCE_KEYVAULT --name slack-webhook | jq -r .value)"

if [[ -n "$SUBFUNCTION" ]]; then
    case "$SUBFUNCTION" in
        flux)
            flux_configmap
            exit 0
            ;;
        *)
            echo ""
            printf "%sERROR %s%s\n" "${red}" "Unknown SUBFUNCTION: $SUBFUNCTION" "${normal}"
            exit 1
            ;;
    esac
fi

#######################################################################################
### Check if all secrets exist in Key Vault
### Read from Azure App Configuration

config_key="base_secrets"
secret_list=$(az appconfig kv show --name "$APP_CONFIG_NAME" --key "$config_key" --query "value" -o tsv 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$secret_list" ]; then
    echo "ERROR: Failed to retrieve key '$config_key' from App Configuration '$APP_CONFIG_NAME'" >&2
    exit 1
fi

# Parse the list into an array
# If it's comma-separated:
IFS=',' read -ra secrets <<< "$secret_list"

# Or if it's a JSON array like ["secret1","secret2","secret3"]:
# mapfile -t secrets < <(echo "$secret_list" | jq -r '.[]')

check_secrets_exist "radix-keyv-c3" "${secrets[@]}"

#######################################################################################
### Check if kubernetes-api-auth-ip-range are defined
### Read from Azure App Configuration
config_key="kubernetes-api-auth-ip-range"
ip_list=$(az appconfig kv show --name "$APP_CONFIG_NAME" --key "$config_key" --query "value" -o tsv 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$ip_list" ]; then
    echo "ERROR: Failed to retrieve key '$config_key' from App Configuration '$APP_CONFIG_NAME'" >&2
    exit 1
fi


#######################################################################################
### Verifying Data Contributor on scope of subscription is activated
###

printf "Verifying that logged in AAD user has Radix Confidential Data Contributor on scope of ${AZ_SUBSCRIPTION_ID}... "
az role assignment list --scope /subscriptions/${AZ_SUBSCRIPTION_ID} --assignee "$(az ad signed-in-user show --query id -o tsv)" --query [].roleDefinitionName -o tsv | grep -E "^Radix Confidential Data Contributor\$"
if [[ "$?" != "0" ]]; then
  echo -e "ERROR: Logged in user is not Radix Confidential Data Contributor on scope of ${AZ_SUBSCRIPTION_ID} subscription. Is Azure resource activated?" >&2
  echo -e "Make sure you have enabled AZ PIM OMNIA RADIX Cluster Admin - ${RADIX_ENVIRONMENT} role" >&2
  exit 1
fi
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
echo -e "   -  BACKUP_NAME                      : $BACKUP_NAME"
echo -e "   -  DEST_CLUSTER                     : $DEST_CLUSTER"
echo -e "   -  FLUX BRANCH                      : $FLUX_BRANCH"
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

if [[ -z "$STORAGACCOUNT" ]]; then
    echo "ERROR: Got no infomation about the Velero StorageAccount." >&2
    exit 1
fi

echo "Makeing sure that Storage Account container $DEST_CLUSTER exists on $STORAGACCOUNT."
CONTAINER=$(az storage container create --name $DEST_CLUSTER --account-name $STORAGACCOUNT --auth-mode login --only-show-errors)
echo ""
# echo "You need to create a pull request to make ready for new cluster"
printf "%s► Adding a new branch: "$DEST_CLUSTER"\n"
git checkout -b $DEST_CLUSTER &> /dev/null
printf "%s► Modify %s%s\n" "${grn}" "${RADIX_PLATFORM_REPOSITORY_PATH}/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/config.yaml to reflect the new cluster" "${normal}"
echo "DO NOT alter the 'activecluster' value yet.."
echo "Press 'space' to continue"
read -r -s -d ' '
printf "Do some terraform tasks..."
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" init
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" apply
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" apply
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/post-clusters" init
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/post-clusters" apply

get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$DEST_CLUSTER" >/dev/null
[[ "$(kubectl config current-context)" != "$DEST_CLUSTER" ]] && exit 1

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
    #######################################################################################
    ### Install ingress-nginx
    ###
    echo ""
    SELECTED_INGRESS_IP_RAW_ADDRESS=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" output -json clusters | jq -r '.[] | select(.cluster=="'${DEST_CLUSTER}'") | .ingressIp')
    kubectl create namespace ingress-nginx --dry-run=client -o yaml |
    kubectl apply -f -

    kubectl create secret generic ingress-nginx-raw-ip \
        --namespace ingress-nginx \
        --from-literal=rawIp="$SELECTED_INGRESS_IP_RAW_ADDRESS" \
        --dry-run=client -o yaml |
        kubectl apply -f -

    echo "controller:
    service:
        loadBalancerIP: $SELECTED_INGRESS_IP_RAW_ADDRESS" > config

    kubectl create secret generic ingress-nginx-ip \
        --namespace ingress-nginx \
        --from-file=./config \
        --dry-run=client -o yaml |
        kubectl apply -f -

    rm config
    printf "Done.\n"

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

    flux_configmap()

    az keyvault secret download \
    --vault-name "$AZ_RESOURCE_KEYVAULT" \
    --name "$FLUX_PRIVATE_KEY_NAME" \
    --file "$FLUX_PRIVATE_KEY_NAME" 2>&1 >/dev/null

    echo "Installing flux with your flux version: v$FLUX_VERSION"
    flux bootstrap git \
    --private-key-file="$FLUX_PRIVATE_KEY_NAME" \
    --url="ssh://git@github.com/equinor/radix-flux" \
    --branch="$FLUX_BRANCH" \
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
fi

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

# Wait for operator to be deployed from flux
echo ""
echo "Waiting for radix-operator to be deployed by flux-operator so that it can handle migrated apps"
echo "If this lasts forever, are you migrating to a cluster without base components installed?"
while [[ "$(kubectl get deploy radix-operator 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5
done
printf " Done."

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
kubectl patch backupstoragelocation default --namespace velero --type merge --dry-run=client --patch "$(cat <<EOF
{
  "spec": {
    "objectStorage": {
      "bucket": "${SOURCE_CLUSTER}"
    }
  }
}
EOF
)"

printf "Making backup of source cluster... "
cat <<EOF | kubectl apply --filename -
apiVersion: velero.io/v1
kind: Backup
metadata:
  labels:
    velero.io/storage-location: default
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
  storageLocation: default
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

echo ""
printf "Restore into destination cluster...\n"
printf "%s► Execute %s%s\n" "${grn}" "$RESTORE_APPS_SCRIPT" "${normal}"
(RADIX_ZONE="$RADIX_ZONE" SOURCE_CLUSTER="$SOURCE_CLUSTER" DEST_CLUSTER="$DEST_CLUSTER" BACKUP_NAME="$BACKUP_NAME" USER_PROMPT="$USER_PROMPT" source "$RESTORE_APPS_SCRIPT")
wait # wait for subshell to finish
printf "Done restoring into cluster."

if [[ $KILL_VELERO_WINDOWS == true ]]; then
    tmux kill-session -t velero
fi

OAUTH2_CLIENT_ID=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -raw app_webconsole_client_id)

kubectl patch configmap env-vars-web --namespace radix-web-console-qa --type merge --patch "$(cat <<EOF
{
  "data": {
    "CMDB_CI_URL": "https://equinor.service-now.com/selfservice?id=form&table=cmdb_ci_business_app&sys_id={CIID}",
    "OAUTH2_AUTHORITY": "https://login.microsoftonline.com/3aa4a235-b6e2-48d5-9195-7fcf05b459b0",
    "OAUTH2_CLIENT_ID": "${OAUTH2_CLIENT_ID}",
    "SERVICENOW_PROXY_SCOPES": "1b4a22f1-d4a1-4b6a-81b2-fd936daf1786/Application.Read"
  }
}
EOF
)"

kubectl patch configmap env-vars-web --namespace radix-web-console-prod --type merge --patch "$(cat <<EOF
{
  "data": {
    "CMDB_CI_URL": "https://equinor.service-now.com/selfservice?id=form&table=cmdb_ci_business_app&sys_id={CIID}",
    "OAUTH2_AUTHORITY": "https://login.microsoftonline.com/3aa4a235-b6e2-48d5-9195-7fcf05b459b0",
    "OAUTH2_CLIENT_ID": "${OAUTH2_CLIENT_ID}",
    "SERVICENOW_PROXY_SCOPES": "1b4a22f1-d4a1-4b6a-81b2-fd936daf1786/Application.Read"
  }
}
EOF
)"

kubectl rollout restart deployment -n radix-web-console-qa web
kubectl rollout restart deployment -n radix-web-console-prod web

printf "Waiting for radix-networkpolicy-canary environments..."
while [[ ! $(kubectl get radixenvironments --output jsonpath='{.items[?(.metadata.labels.radix-app=="radix-networkpolicy-canary")].metadata.name}') ]]; do
    printf "."
    sleep 5
done
echo ""

printf "Waiting for server component in radix-api-qa namespace to get ready.\n"
printf "If this takes forever, monitor the deployment..."
while [[ ! $(kubectl get deployments -n radix-api-qa server -o jsonpath={.status.availableReplicas}) ]]; do 
    printf "."
    sleep 5
done
echo ""

printf "Waiting for server component in radix-api-prod namespace to get ready.\n"
printf "If this takes forever, monitor the deployment..."
while [[ ! $(kubectl get deployments -n radix-api-prod server -o jsonpath={.status.availableReplicas}) ]]; do
    printf "."
    sleep 5
done

# Update networkpolicy canary with HTTP password to access endpoint for scheduling batch job
printf "\n%s► Execute %s%s\n" "${grn}" "$UPDATE_NETWORKPOLICY_CANARY_SECRET_SCRIPT" "${normal}"
(RADIX_ZONE="$RADIX_ZONE" CLUSTER_NAME="$DEST_CLUSTER" STAGING="$STAGING" source "$UPDATE_NETWORKPOLICY_CANARY_SECRET_SCRIPT")
wait # wait for subshell to finish
echo ""

#######################################################################################
### Check keyvault secrets
###

# if [[ -d "${RADIX_ZONE_PATH}" ]]; then
#     for filename in "${RADIX_ZONE_PATH}"/*.env; do
#         if [[ "${filename}" == *test* ]]; then continue; fi
#         radix_zone_env="${filename}"

#         # Check keyvault secrets
#         printf "%s► Execute %s%s\n" "${grn}" "$CHECK_KEYVAULT_SECRETS" "${normal}"
#         (RADIX_ZONE_ENV=${radix_zone_env} USER_PROMPT="$USER_PROMPT" source "$CHECK_KEYVAULT_SECRETS")
#         wait # wait for subshell to finish
#         echo ""
#     done
#     unset radix_zone_env
# else
#     printf "ERROR: The radix-zone path is not found\n" >&2
# fi

#######################################################################################
### Update Radix API env vars
###



echo ""
printf "%s► Execute %s%s\n" "${grn}" "$RADIX_API_ENV_VAR_SCRIPT" "${normal}"
(RADIX_ZONE="$RADIX_ZONE" CLUSTER_NAME="$DEST_CLUSTER" STAGING="$STAGING" source "$RADIX_API_ENV_VAR_SCRIPT")
wait # wait for subshell to finish
echo ""

#######################################################################################
### Check appreg secrets
###

# printf "%s► Execute %s%s\n" "${grn}" "$CHECK_APPREG_SECRETS" "${normal}"
# (RADIX_ZONE_ENV=${RADIX_ZONE_ENV} USER_PROMPT="$USER_PROMPT" source "$CHECK_APPREG_SECRETS")
# wait # wait for subshell to finish
# echo ""

#######################################################################################
### Final post tasks
###

printf "\n"
printf "%sYou need to do following tasks to activate cluster:%s\n" "${yel}" "${normal}"
printf "%s► Modify $RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/config.yaml to reflect active cluster (activecluster: true) %s%s\n" "${grn}" "${normal}"
printf "%s► Execute: 'terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" apply -target module.aks' %s%s\n" "${grn}" "${normal}"
printf "%s► Execute: 'terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/post-clusters" apply -target module.dns_config' %s%s\n" "${grn}" "${normal}"
printf "%s► Execute: 'git push & merge branch '${DEST_CLUSTER}' to master' %s%s\n" "${grn}" "${normal}"
printf "%s► Modify: postBuild.yaml file in radix-flux to reflect 'ACTIVE_CLUSTER: ${DEST_CLUSTER}' and merge %s%s\n" "${grn}" "${normal}"
echo ""
printf "Post a slack message about new active cluster in $RADIX_ZONE.\n"
printf "Done.\n"

