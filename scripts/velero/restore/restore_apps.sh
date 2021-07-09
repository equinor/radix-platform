#!/bin/bash

#######################################################################################
### PURPOSE
###

# Restore radix applications using a velero backup in any radix cluster.
# It will NOT restore PV or PVC.

# Regarding CR Restore manifests
# A restore operation can be defined as a velero custom resource of type "Restore".
# See example "restore_rr.yaml" for restoring radix registrations.
# These manifests are templated using shell variables.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - SOURCE_CLUSTER      : Example: "test-2", "weekly-93"
# - BACKUP_NAME         : Example: all-hourly-20190703064411

# Optional:
# - DEST_CLUSTER        : Example: "test-2", "weekly-93"
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# Example: Restore into same cluster from where the backup was done
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env SOURCE_CLUSTER=weekly-25 BACKUP_NAME=all-hourly-20190703064411 ./restore_apps.sh

# Example: Restore into different cluster from where the backup was done
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env SOURCE_CLUSTER=dev-1 DEST_CLUSTER=dev-2 BACKUP_NAME=all-hourly-20190703064411 ./restore_apps.sh

#######################################################################################
### DEVELOPMENT
###

# To "reset" the destination cluster when testing this script then you can use the "reset_restore_apps.sh" script.

#######################################################################################
### KNOWN ISSUES
###

# >>  Missing "envsubst" on mac
#     Tool "envsubst" is available by default in linux, but not in macOs.
#     For macOs it is included in the "gettext" package and is installed and linked using brew
#     $brew install gettext
#     $brew link --force gettext

# >>  Restore resource X failed
#     We need to restore radix resources in a specific order and give the radix-operator enough time to work with
#     them before moving on to restoring the next resource.
#     This time interval is as for now simply a sleep for a "I hope this is long enough" time.
#     Often adjusting the time before the resource restore that failed will fix the problem.
#     The "ultimate" solution is to have a proper check that the radix-operator has finished processing the
#     previous resource before continuing on, but this is a TODO in both this script and radix-operator (future: CR status field).

#######################################################################################
### START
###

echo ""
echo "Start restore apps... "

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
  echo -e "\nError: Azure-CLI not found in PATH. Exiting..." >&2
  exit 1
}
hash kubectl 2>/dev/null || {
  echo -e "\nError: kubectl not found in PATH. Exiting..." >&2
  exit 1
}
hash envsubst 2>/dev/null || {
  echo -e "\nError: envsubst not found in PATH. Exiting..." >&2
  exit 1
}
hash velero 2>/dev/null || {
  echo -e "\nError: velero not found in PATH. Exiting..." >&2
  exit 1
}
printf "Done."
echo ""

#######################################################################################
### Resolve dependencies on other scripts
###

WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ADD_REPLY_URL_SCRIPT="$WORKDIR_PATH/../../add_reply_url_for_cluster.sh"
if ! [[ -x "$ADD_REPLY_URL_SCRIPT" ]]; then
  # Print to stderror
  echo "The replyUrl script is not found or it is not executable in path $ADD_REPLY_URL_SCRIPT" >&2
fi

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
  echo "Please provide SOURCE_CLUSTER." >&2
  exit 1
fi

if [[ -z "$BACKUP_NAME" ]]; then
  echo "Please provide BACKUP_NAME." >&2
  exit 1
fi

# Optional inputs

if [[ -z "$DEST_CLUSTER" ]]; then
  DEST_CLUSTER="$SOURCE_CLUSTER"
fi

if [[ -z "$USER_PROMPT" ]]; then
  USER_PROMPT=true
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
echo -e "Restore apps will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  SOURCE_CLUSTER                   : $SOURCE_CLUSTER"
echo -e "   -  DEST_CLUSTER                     : $DEST_CLUSTER"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  BACKUP_NAME                      : $BACKUP_NAME"
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
### Support funcs
###

# RRs are synced when there is a corresponding app namespace
# for every RR
function please_wait_until_rr_synced() {
  local resource="rr"
  local allCmd="kubectl get rr -o custom-columns=':metadata.name' --no-headers"
  local currentCmd="kubectl get ns -o custom-columns=':metadata.name'"
  local condition="grep '\-app'"

  please_wait_for_reconciling_withcondition "$resource" "$allCmd" "$currentCmd" "$condition"
}

# RAs are synced when number of environments = number of environment namespaces
function please_wait_until_ra_synced() {
  local resource="ra"
  local allCmd="kubectl get ra --all-namespaces -o custom-columns=':spec.environments[*].name' | tr ',' '\n'"
  local currentCmd="kubectl get ns --selector=app-wildcard-sync=app-wildcard-tls-cert"
  # No condition
  local condition="grep ''"

  please_wait_for_reconciling_withcondition "$resource" "$allCmd" "$currentCmd" "$condition"
}

function please_wait() {
  # Loop for $1 iterations.
  # For every iteration, sleep 1s and print $2 delimiter.
  local iteration_end="${1:-5}"
  local delimiter_default="."
  local delimiter="${2:-$delimiter_default}"
  local iterator=0

  while [[ "$iterator" != "$iteration_end" ]]; do
    iterator="$((iterator + 1))"
    printf "$delimiter"
    sleep 1s
  done
  echo "Done."
}

# Common function for reconciling resources that have a status.condition field. When all have
# a status.condition != <none> they can be considered reconciled
function please_wait_for_reconciling() {
  local resource="${1}"
  local allCmd="kubectl get $resource --all-namespaces"
  local currentCmd="kubectl get $resource --all-namespaces -o custom-columns=':status.condition'"
  local condition="grep -v '<none>'"

  please_wait_for_reconciling_withcondition "$resource" "$allCmd" "$currentCmd" "$condition"
}

# Common function for reconciling resources
function please_wait_for_reconciling_withcondition() {
  local resource="${1}"
  local allCmd="${2}"
  local currentCmd="${3}"
  local condition="${4}"

  # Sometimes reconciling gets stuck
  local treshholdPercentage=98
  local treshholdBroken=0

  please_wait_for_existance_of_resource "$resource"

  local all="$(bash -c "$allCmd" | wc -l | xargs)"
  local current="$(bash -c "$currentCmd" | bash -c "$condition" | wc -l | xargs)"

  while [[ "$current" -lt "$all" ]]; do
    percentage=$((current * 100 / all))
    showProgress $percentage
    sleep 5s

    if [[ "$treshholdBroken" == '10' ]]; then
      break
    fi

    if [[ "$percentage" -gt "$treshholdPercentage" ]]; then
      treshholdBroken="$((treshholdBroken + 1))"
    fi

    current=($(bash -c "$currentCmd" | bash -c "$condition" | wc -l | xargs))
  done

  showProgress 100
}

# It takes a little while before all resources are visible in the cluster after having
# been restored
function please_wait_for_existance_of_resource() {
  local resource="${1}"

  exists=($(kubectl get $resource --all-namespaces 2>/dev/null | wc -l | xargs))

  while [[ $exists == 0 ]]; do
    printf "$iterator"
    sleep 5s
    exists=($(kubectl get $resource --all-namespaces 2>/dev/null | wc -l | xargs))
  done

  please_wait_for_all_resources "$resource"
}

function please_wait_for_all_resources() {
  local resource="${1}"
  local command="kubectl get $resource --all-namespaces"

  # Sometimes it takes a bit of time before all resources
  # are visible in the cluster
  first=($($command 2>/dev/null | wc -l | xargs))

  sleep 5s
  second=($($command 2>/dev/null | wc -l | xargs))

  # The the resources stop growing, we
  # can assume all are visible
  while [[ $((second - first)) != 0 ]]; do
    first=($($command 2>/dev/null | wc -l | xargs))
    printf "$iterator"
    sleep 5s
    second=($($command 2>/dev/null | wc -l | xargs))
  done
}

function showProgress() {
  local percentage="${1:-5}"

  if [[ $percentage < 0 ]]; then
    percentage=0
  fi

  local progress=""
  local iterator=$percentage

  while [[ "$iterator" > 0 ]]; do
    iterator="$((iterator - 1))"
    progress="$progress#"
  done

  progress="$progress  ($percentage%)\r"
  echo -ne $progress
}

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
echo ""
echo "Connecting kubectl to vendelo-destination..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$AZ_RESOURCE_GROUP_CLUSTERS" --name "$DEST_CLUSTER" 2>&1)"" == *"ERROR"* ]]; then
  # Send message to stderr
  echo -e "Error: Cluster \"$DEST_CLUSTER\" not found." >&2
  exit 0
fi

#######################################################################################
### Configure velero for restore in destinaton
###

echo ""
echo "Configure velero for restore in destination cluster \"$DEST_CLUSTER\"..."

# Set velero-destination to read-only
kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server", "--restore-only"]}]}}}}'
# Set velero in destination to read source backup location
PATCH_JSON="$(
  cat <<END
{
   "spec": {
      "objectStorage": {
         "bucket": "$SOURCE_CLUSTER"
      }
   }
}
END
)"
kubectl patch BackupStorageLocation azure -n velero --type merge --patch "$(echo $PATCH_JSON)"

echo ""
echo "Wait for backup \"$BACKUP_NAME\" to be available in destination cluster \"$DEST_CLUSTER\" before we can restore..."
while [[ "$(velero backup describe $BACKUP_NAME 2>&1)" == *"error"* ]]; do
  printf "."
  sleep 2s
done
echo "Done."

#######################################################################################
### Restart operator to get proper metrics
###

echo "Restarting Radix operator."
$(kubectl patch deploy radix-operator -p "[{'op': 'replace', 'path': "/spec/replicas",'value': 0}]" --type json 2>&1 >/dev/null)
sleep 2s
$(kubectl patch deploy radix-operator -p "[{'op': 'replace', 'path': "/spec/replicas",'value': 1}]" --type json 2>&1 >/dev/null)
echo "Done."

#######################################################################################
### Restore data
###

#######################################################################################
### Restore secrets
###

echo ""
echo "Restore app specific secrets..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' <${WORKDIR_PATH}/restore_secret.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

echo ""
echo "Wait for secrets to be picked up by radix-operator..."
please_wait_for_all_resources "secret"

#######################################################################################
### Restore apps
###

echo ""
echo "Restore app registrations..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' <${WORKDIR_PATH}/restore_rr.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

echo ""
echo "Wait for registrations to be picked up by radix-operator..."
please_wait_until_rr_synced

echo ""
echo "Restore app config..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' <${WORKDIR_PATH}/restore_ra.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

# TODO: Is the current mechansim sufficient?
echo ""
echo "Wait for app config to be picked up by radix-operator..."
please_wait_until_ra_synced

echo ""
echo "Restore deployments..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' <${WORKDIR_PATH}/restore_rd.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

echo "Wait for deployments to be picked up by radix-operator..."
please_wait_for_reconciling "rd"

#######################################################################################
### Update replyUrls for those radix apps that require AD authentication
###

echo ""
echo "Updating replyUrls for those radix apps that require AD authentication"

echo ""
echo "Adding replyUrl for Grafana..."
(AAD_APP_NAME="radix-cluster-aad-server-${RADIX_ENVIRONMENT}" K8S_NAMESPACE="default" K8S_INGRESS_NAME="grafana" REPLY_PATH="/login/generic_oauth" USER_PROMPT="$USER_PROMPT" source "$ADD_REPLY_URL_SCRIPT")
wait # wait for subshell to finish
printf "Done."

# Update replyUrl for web-console
AUTH_PROXY_COMPONENT="auth"
AUTH_PROXY_REPLY_PATH="/oauth2/callback"
RADIX_WEB_CONSOLE_ENV="prod"
if [[ $CLUSTER_TYPE  == "development" ]]; then
  echo "Development cluster uses QA web-console"
  RADIX_WEB_CONSOLE_ENV="qa"
fi
WEB_CONSOLE_NAMESPACE="radix-web-console-$RADIX_WEB_CONSOLE_ENV"

echo ""
echo "Waiting for web-console ingress to be ready so we can add replyUrl to web console aad app..."
while [[ "$(kubectl get ing $AUTH_PROXY_COMPONENT -n $WEB_CONSOLE_NAMESPACE 2>&1)" == *"Error"* ]]; do
  printf "."
  sleep 5s
done
echo "Ingress is ready, adding replyUrl... "

echo ""
echo "Adding replyUrl for radix web-console..."
# The web console has an aad app per cluster type. This script does not know about cluster type, so we will have to go with subscription environment.
if [[ "$RADIX_ENVIRONMENT" == "dev" ]]; then
  (AAD_APP_NAME="Omnia Radix Web Console - Development Clusters" K8S_NAMESPACE="$WEB_CONSOLE_NAMESPACE" K8S_INGRESS_NAME="$AUTH_PROXY_COMPONENT" REPLY_PATH="$AUTH_PROXY_REPLY_PATH" USER_PROMPT="$USER_PROMPT" source "$ADD_REPLY_URL_SCRIPT")
  wait # wait for subshell to finish
  (AAD_APP_NAME="Omnia Radix Web Console - Playground Clusters" K8S_NAMESPACE="$WEB_CONSOLE_NAMESPACE" K8S_INGRESS_NAME="$AUTH_PROXY_COMPONENT" REPLY_PATH="$AUTH_PROXY_REPLY_PATH" USER_PROMPT="$USER_PROMPT" source "$ADD_REPLY_URL_SCRIPT")
  wait # wait for subshell to finish
fi
if [[ "$RADIX_ENVIRONMENT" == "prod" ]]; then
  (AAD_APP_NAME="Omnia Radix Web Console - Production Clusters" K8S_NAMESPACE="$WEB_CONSOLE_NAMESPACE" K8S_INGRESS_NAME="$AUTH_PROXY_COMPONENT" REPLY_PATH="$AUTH_PROXY_REPLY_PATH" USER_PROMPT="$USER_PROMPT" source "$ADD_REPLY_URL_SCRIPT")
  wait # wait for subshell to finish
fi
printf "Done."

#######################################################################################
### Restore jobs
###

echo ""
echo "Restore jobs..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' <${WORKDIR_PATH}/restore_rj.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

echo "Wait for jobs to be picked up by radix-operator..."
please_wait_for_reconciling "rj"

#######################################################################################
### Configure velero back to normal operation in destination
###

echo ""
echo "Configure velero back to normal operation in destination..."

# Set velero in destination to read destination backup location
PATCH_JSON="$(
  cat <<END
{
   "spec": {
      "objectStorage": {
         "bucket": "$DEST_CLUSTER"
      }
   }
}
END
)"
kubectl patch BackupStorageLocation azure -n velero --type merge --patch "$(echo $PATCH_JSON)"
# Set velero in read/write mode
kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server"]}]}}}}'

#######################################################################################
### Done!
###

echo ""
echo "All restore tasks are done!"

# Print restore status
echo "Run \"velero restore get\" to get latest status:"
velero restore get

echo "Done restoring apps"
