#!/usr/bin/env bash

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
# - RADIX_ZONE          : dev | playground | prod | c2
# - SOURCE_CLUSTER      : Example: "test-2", "weekly-93"
# - BACKUP_NAME         : Example: all-hourly-20190703064411

# Optional:
# - DEST_CLUSTER        : Example: "test-2", "weekly-93"
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# Example: Restore into same cluster from where the backup was done
# RADIX_ZONE=dev SOURCE_CLUSTER=weekly-44 BACKUP_NAME=all-hourly-20251030060001 ./restore_apps.sh

# Example: Restore into different cluster from where the backup was done
# RADIX_ZONE=dev  SOURCE_CLUSTER=dev-1 DEST_CLUSTER=dev-2 BACKUP_NAME=all-hourly-20250703064411 ./restore_apps.sh

# Example: Disaster recovery scenario. BACKUP_NAME must be available in SOURCE_CLUSTER(ie the cluster you are restoring to)
# RADIX_ZONE=d1 MODE=DR SOURCE_CLUSTER=disaster-22 BACKUP_NAME=all-hourly-20250605100053 ./restore_apps.sh

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
set +x

echo ""
echo "Start restore apps... "

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
hash envsubst 2>/dev/null || {
  echo -e "\nERROR: envsubst not found in PATH. Exiting..." >&2
  exit 1
}
hash velero 2>/dev/null || {
  echo -e "\nERROR: velero not found in PATH. Exiting..." >&2
  exit 1
}
printf "Done."
echo ""

#######################################################################################
### Resolve dependencies on other scripts
###

WORKDIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh
#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2|c3)$ ]] || [[ $MODE=DR ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2|c3" >&2
    exit 1
fi

if [[ $MODE == "DR" ]]; then
  dr_zone_message $RADIX_ZONE
fi

if [[ -z "$SOURCE_CLUSTER" ]]; then
  echo "ERROR: Please provide SOURCE_CLUSTER." >&2
  exit 1
fi

if [[ -z "$BACKUP_NAME" ]]; then
  echo "ERROR: Please provide BACKUP_NAME." >&2
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
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")

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
  echo ""
fi

#######################################################################################
### Support funcs
###

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
    sleep 1
  done
  echo "Done."
}

# It takes a little while before the velero restore object has state "phase: Completed".
function please_wait_for_restore_to_be_completed() {
  local resource="${1}"
  local command="kubectl get restore --namespace velero $BACKUP_NAME-$resource -o jsonpath={.status}"

  while : ; do
    status=$($command 2>/dev/null)

    itemsRestored=$(jq .progress.itemsRestored -r <(echo "$status"))
    if [[ $itemsRestored != 'null' ]]; then
      totalItems=$(jq .progress.totalItems -r <(echo "$status"))
      progress="Progress: $itemsRestored of $totalItems items\r"
      echo -ne $progress
    fi
    
    phase=$(jq .phase -r <(echo "$status"))
    if [[ $phase == 'Completed' ]]; then
      break
    fi
    sleep 2
  done
}

wait_for_velero() {
  local resource="${1}"
  local command="kubectl get $resource --namespace velero"

  check=($($command 2>/dev/null | wc -l))

  printf "Waiting for %s..." "$resource"

  while [[ $check -lt 2 ]]; do
    check=($($command 2>/dev/null | wc -l))
    printf "."
    sleep 5
  done

  printf " Done.\n"
}

stop_radix_operator() {
  printf "Stop radix-operator"
  kubectl scale deployment radix-operator --namespace default --replicas=0

  printf "Waiting for radix-operator is stopped\n"
  while [[ $(kubectl get pods --selector='app.kubernetes.io/name=radix-operator' --namespace default -o name | wc -l) -ne 0 ]]; do
    sleep 5
  done
  printf " Done.\n"
}

start_radix_operator() {
  printf "Start radix-operator"
  kubectl scale deployment radix-operator --namespace default --replicas=1

  printf "Waiting for radix-operator is started"
  while [[ $(kubectl get pods --selector='app.kubernetes.io/name=radix-operator' --namespace default -o name | wc -l) -eq 0 ]]; do
    sleep 5
  done
  printf " Done.\n"
}

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
echo "Connecting kubectl to velero-destination..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$DEST_CLUSTER" || {
  # Send message to stderr
  echo -e "ERROR: Cluster \"$DEST_CLUSTER\" not found." >&2
  exit 0
}

#######################################################################################
### Verify cluster access
###
verify_cluster_access

#######################################################################################
### Configure velero for restore in destinaton
###

echo ""
echo "Configure velero for restore in destination cluster \"$DEST_CLUSTER\"..."

# Set velero in destination to read source backup location
PATCH_JSON="$(
  cat <<END
{
    "spec": {
       "accessMode":"ReadOnly",
       "objectStorage": {
            "bucket": "$SOURCE_CLUSTER"
       }
    }
 }
END
)"

flux suspend ks -n flux-system velero
wait_for_velero "BackupStorageLocation default"
kubectl patch BackupStorageLocation default --namespace velero --type merge --patch "$(echo $PATCH_JSON)"

echo ""
printf "Wait for backup \"%s\" to be available in destination cluster \"%s\" before we can restore..." "$BACKUP_NAME" "$DEST_CLUSTER"
while [[ "$(velero backup describe $BACKUP_NAME 2>&1)" == *"error"* ]]; do
  printf "."
  sleep 5
done
printf " Done.\n"

#######################################################################################
### Stop operator to avoid reconciliation conflicts while restoring
###

stop_radix_operator

#######################################################################################
### Restore secrets
###

echo ""
echo "Restore app specific secrets..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' <${WORKDIR_PATH}/restore_secret.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

echo ""
echo "Wait for secrets to be restored..."
please_wait_for_restore_to_be_completed "secret"

#######################################################################################
### Restore configmaps
###

echo ""
echo "Restore app specific configmaps..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' <${WORKDIR_PATH}/restore_configmap.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

echo ""
echo "Wait for configmaps to be restored..."
please_wait_for_restore_to_be_completed "configmaps"

#######################################################################################
### Restore Radix Registration resources
###

echo ""
echo "Restore Radix Registration resources..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' <${WORKDIR_PATH}/restore_radix_rr.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

echo ""
echo "Wait for Radix registration resources to be restored..."
please_wait_for_restore_to_be_completed "radix-rr"

#######################################################################################
### Restore remaining Radix resources
###

echo ""
echo "Restore remaining Radix resources..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' <${WORKDIR_PATH}/restore_radix.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

echo ""
echo "Wait for remaining Radix resources to be restored..."
please_wait_for_restore_to_be_completed "radix"

#######################################################################################
### Start operator to reconcile Radix resources
###
start_radix_operator

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
       "accessMode":"ReadWrite",
       "objectStorage": {
            "bucket": "$DEST_CLUSTER"
       }
    }
 }
END
)"

# Set velero in read/write mode
kubectl patch BackupStorageLocation default --namespace velero --type merge --patch "$(echo $PATCH_JSON)"
flux resume ks -n flux-system velero

#######################################################################################
### Done!
###

echo ""
echo "All restore tasks are done!"

# Print restore status
echo "Run \"velero restore get\" to get latest status:"
velero restore get

echo "Done restoring apps"
