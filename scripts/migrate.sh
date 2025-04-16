#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Migrate the radix platform from cluster to cluster

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE          : dev|playground|prod|c2
# - SOURCE_CLUSTER      : Ex: "test-2", "weekly-93"
# - DEST_CLUSTER        : Ex: "test-2", "weekly-93"

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE=dev SOURCE_CLUSTER=weekly-26 DEST_CLUSTER=cilium-26 ./migrate.sh > >(tee -a /tmp/stdout.log) 2> >(tee -a /tmp/stderr.log >&2)

# or without log:
# RADIX_ZONE=dev SOURCE_CLUSTER=weekly-50 DEST_CLUSTER=weekly-51 ./migrate.sh


# DISASTER RECOVERY:
# RADIX_ZONE=dev SOURCE_CLUSTER=weekly-19 BACKUP_NAME=all-hourly-20220510150047 DEST_CLUSTER=weekly-19c ./migrate.sh



#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2" >&2
    exit 1
fi

#######################################################################################
### Check for prerequisites binaries
###

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

echo ""
printf "Check for neccesary executables... \n"
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}

AZ_CLI=$(az version --output json | jq -r '."azure-cli"')
MIN_AZ_CLI="2.57.0"
if [ $(version $AZ_CLI) -lt $(version "$MIN_AZ_CLI") ]; then
    printf ""${yel}"Please update az cli to ${MIN_AZ_CLI}. You got version $AZ_CLI."${normal}"\n"
    exit 1
fi

hash cilium 2>/dev/null || {
    echo -e "\nERROR: cilium not found in PATH. Exiting..." >&2
    exit 1
}

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

hash yq 2>/dev/null || {
    echo -e "\nERROR: yq not found in PATH. Exiting..." >&2
    exit 1
}

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
REQ_FLUX_VERSION="2.5.1"
FLUX_VERSION=$(flux --version | awk '{print $3'})
if [[ "$FLUX_VERSION" != "${REQ_FLUX_VERSION}" ]]; then
    printf ""${yel}"Please update flux cli to ${REQ_FLUX_VERSION}. You got version $FLUX_VERSION${normal}\n"
    exit 1
fi


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

hash terraform 2>/dev/null || {
    echo -e "\nERROR: terraform not found in PATH. Exiting..." >&2
    exit 1
}

printf "Done.\n"

#######################################################################################
### Read Zone Config
###


if [[ -z "$SOURCE_CLUSTER" ]]; then
    echo "ERROR: Please provide SOURCE_CLUSTER" >&2
    exit 1
fi

if [[ -z "$DEST_CLUSTER" ]]; then
    echo "ERROR: Please provide DEST_CLUSTER" >&2
    exit 1
fi

# Source util scripts
RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
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

RESTORE_APPS_SCRIPT="$WORKDIR_PATH/velero/restore/restore_apps.sh"
if ! [[ -x "$RESTORE_APPS_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The restore apps script is not found or it is not executable in path $RESTORE_APPS_SCRIPT" >&2
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
AZ_RADIX_ZONE_LOCATION=$(yq '.location' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_DNS=$(jq -r .dnz_zone <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_KEYVAULT=$(jq -r .keyvault <<< "$RADIX_RESOURCE_JSON")
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
AZ_SUBSCRIPTION_NAME=$(yq '.subscription_shortname' <<< "$RADIX_ZONE_YAML")
CLUSTER_NAME="$DEST_CLUSTER"
IMAGE_REGISTRY=$(jq -r .acr <<< "$RADIX_RESOURCE_JSON")
MIGRATION_STRATEGY="aa"
RADIX_ENVIRONMENT=$(yq '.radix_environment' <<< "$RADIX_ZONE_YAML")
STORAGACCOUNT=$(jq -r .velero_sa <<< "$RADIX_RESOURCE_JSON")

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
echo "You need to create a pull request to make ready for new cluster"
printf "%s► Adding a new branch: "$DEST_CLUSTER"\n"
git checkout -b $DEST_CLUSTER &> /dev/null
printf "%s► Modify %s%s\n" "${grn}" "${RADIX_PLATFORM_REPOSITORY_PATH}/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/config.yaml to reflect the new cluster" "${normal}"
echo "DO NOT alter the 'activecluster' value yet.."
echo "Press 'space' to continue"
read -r -s -d ' '
printf "%s► Adding file context to index\n"
git add ${RADIX_PLATFORM_REPOSITORY_PATH}/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/config.yaml &> /dev/null
printf "%s► Git commit - Add new Radix Cluster in ${DEST_CLUSTER}\n"
git commit -m "Add new Radix Cluster in ${DEST_CLUSTER}" &> /dev/null
printf "%s► Git Push - Add new Radix Cluster in $DEST_CLUSTER\n"
git push --set-upstream origin ${DEST_CLUSTER} &> /dev/null
echo "- Create a pull request to master"
echo "- Monitor the github action and the result"
echo "- After approval, run the GitHub Action 'AKS Apply', and tick of the 'Terraform Apply' checkbox"
echo "- The Pre-cluster task will now be executed, and the new cluster will be created"
echo "Press 'space' to continue"
read -r -s -d ' '

get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$DEST_CLUSTER" >/dev/null
[[ "$(kubectl config current-context)" != "$DEST_CLUSTER" ]] && exit 1

printf "Do some terraform tasks..."
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" init
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" apply
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/post-clusters" init
terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/post-clusters" apply


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

    # list of public ips assigned to the cluster
    printf "\nGetting list of public ips assigned to $CLUSTER_NAME..."
    ASSIGNED_IPS="$(az network public-ip list \
        --query "[?ipConfiguration.resourceGroup=='MC_${AZ_RESOURCE_GROUP_CLUSTERS}_${CLUSTER_NAME}_${AZ_RADIX_ZONE_LOCATION}'].ipAddress" \
        --output json)"

    if [[ "$ASSIGNED_IPS" == "[]" ]]; then
        echo "ERROR: Could not find Public IP of cluster." >&2
    else
        # Loop through list of IPs and create a comma separated string.
        for ipaddress in $(echo $ASSIGNED_IPS | jq -cr '.[]'); do
            if [[ -z $IP_LIST ]]; then
                IP_LIST=$(echo $ipaddress)
            else
                IP_LIST="$IP_LIST,$(echo $ipaddress)"
            fi
        done
        printf "...Done\n"
    fi

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
        --from-literal=activeClusterIPs="$IP_LIST" \
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
    --branch="master" \
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

# Define web console variables
RADIX_WEB_CONSOLE_ENV="prod"
if [[ $CLUSTER_TYPE == "development" ]]; then
    # Development cluster uses QA web-console
    RADIX_WEB_CONSOLE_ENV="qa"
fi

# Update web console web component with list of all IPs assigned to the cluster type (development|playground|production)
CLUSTER_EGRESS_IPS=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -raw egress_ips)
CLUSTER_OIDC_ISSUER_URL=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/pre-clusters" output -json | jq -r '.oidc_issuer_url.value["'${DEST_CLUSTER}'"]')
OAUTH2_CLIENT_ID=$(terraform -chdir="$RADIX_PLATFORM_REPOSITORY_PATH/terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/base-infrastructure" output -raw app_webconsole_client_id)

kubectl patch configmap env-vars-web --namespace radix-web-console-qa --type merge --patch "$(cat <<EOF
{
  "data": {
    "CLUSTER_EGRESS_IPS": "${CLUSTER_EGRESS_IPS}",
    "CLUSTER_INGRESS_IPS": "${SELECTED_INGRESS_IP_RAW_ADDRESS}",
    "CLUSTER_OIDC_ISSUER_URL": "${CLUSTER_OIDC_ISSUER_URL}",
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
    "CLUSTER_EGRESS_IPS": "${CLUSTER_EGRESS_IPS}",
    "CLUSTER_INGRESS_IPS": "${SELECTED_INGRESS_IP_RAW_ADDRESS}",
    "CLUSTER_OIDC_ISSUER_URL": "${CLUSTER_OIDC_ISSUER_URL}",
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

printf "Waiting for radix-networkpolicy-canary environments... "
while [[ ! $(kubectl get radixenvironments --output jsonpath='{.items[?(.metadata.labels.radix-app=="radix-networkpolicy-canary")].metadata.name}') ]]; do
    printf "."
    sleep 5
done
printf "Done.\n"

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

printf "\n"
printf "%sDone.%s\n" "${grn}" "${normal}"
printf "\n\n\n %sRemember to patch ./terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/config.yaml to reflect active cluster (activecluster: true) and patch activeClusterName in radix-flux!%s\n\n" "${grn}" "${normal}"
printf "TODO: Make the activecluster: true trigger a github action"
