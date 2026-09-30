#!/usr/bin/env bash

set -euo pipefail

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
# - DEST_CLUSTER        : Example: "test-2", "weekly-93"

# Optional:
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
source "${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh"
#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ -z "${RADIX_ZONE:-}" ]]; then
  echo "ERROR: Please provide RADIX_ZONE." >&2
  exit 1
fi

if [[ ! $RADIX_ZONE =~ ^(dev|playground|prod|c2|c3)$ ]] && [[ ${MODE:-} != "DR" ]]; then
  echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2|c3" >&2
  exit 1
fi

echo "RADIX_ZONE: $RADIX_ZONE"

if [[ ${MODE:-} == "DR" ]]; then
  dr_zone_message "$RADIX_ZONE"
fi

if [[ -z "${SOURCE_CLUSTER:-}" ]]; then
  echo "ERROR: Please provide SOURCE_CLUSTER." >&2
  exit 1
fi

if [[ -z "${BACKUP_NAME:-}" ]]; then
  echo "ERROR: Please provide BACKUP_NAME." >&2
  exit 1
fi

if [[ -z "${DEST_CLUSTER:-}" ]]; then
  echo "ERROR: Please provide DEST_CLUSTER." >&2
  exit 1
fi

if [[ -z "${USER_PROMPT:-}" ]]; then
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

# It takes a little while before the velero restore object reaches a terminal phase.
function please_wait_for_restore_to_be_completed() {
  local resource="${1}"
  local command=(kubectl --context "$DEST_CLUSTER" get restore --namespace velero "$BACKUP_NAME-$resource" -o 'jsonpath={.status}')
  local status itemsRestored totalItems progress phase

  while true; do
    if ! status=$("${command[@]}" 2>&1); then
      printf '\nERROR: Failed to query Velero restore "%s-%s":\n%s\n' \
        "$BACKUP_NAME" "$resource" "$status" >&2
      return 1
    fi

    itemsRestored=$(jq -r '.progress.itemsRestored // "null"' <<< "$status")
    if [[ $itemsRestored != 'null' ]]; then
      totalItems=$(jq -r '.progress.totalItems // "null"' <<< "$status")
      progress="Progress: $itemsRestored of $totalItems items\r"
      echo -ne "$progress"
    fi
    
    phase=$(jq -r '.phase // ""' <<< "$status")
    case $phase in
      Completed)
        return 0
        ;;
      Failed|FailedValidation|PartiallyFailed)
        printf '\nERROR: Velero restore "%s-%s" finished with phase "%s".\n' "$BACKUP_NAME" "$resource" "$phase" >&2
        return 1
        ;;
    esac
    sleep 2
  done
}

wait_for_velero() {
  local resource="${1}"
  local command=(kubectl --context "$DEST_CLUSTER" get $resource --namespace velero)

  printf "Waiting for %s..." "$resource"

  for _ in {1..360}; do
    if "${command[@]}" >/dev/null 2>&1; then
      printf " Done.\n"
      return 0
    fi
    printf "."
    sleep 5
  done

  printf '\nERROR: Timed out waiting for %s (30 minutes). Last query result:\n' "$resource" >&2
  "${command[@]}" >&2 || true
  return 1
}

stop_radix_operator() {
  printf "Stop radix-operator"
  kubectl --context "$DEST_CLUSTER" scale deployment radix-operator --namespace default --replicas=0

  printf "Waiting for radix-operator is stopped\n"
  while [[ $(kubectl --context "$DEST_CLUSTER" get pods --selector='app.kubernetes.io/name=radix-operator' --namespace default -o name | wc -l) -ne 0 ]]; do
    sleep 5
  done
  printf " Done.\n"
}

VELERO_SUSPENDED=false
BACKUP_LOCATION_PATCHED=false

cleanup_velero_configuration() {
  local cleanup_exit_code=0
  local patch_json

  if [[ $BACKUP_LOCATION_PATCHED == true ]]; then
    patch_json="$(
      cat <<END
{
  "spec": {
    "accessMode": "ReadWrite",
    "objectStorage": {
      "bucket": "$DEST_CLUSTER"
    }
  }
}
END
    )"
    if kubectl --context "$DEST_CLUSTER" patch BackupStorageLocation default --namespace velero --type merge --patch "$patch_json"; then
      BACKUP_LOCATION_PATCHED=false
    else
      cleanup_exit_code=1
    fi
  fi

  if [[ $VELERO_SUSPENDED == true ]]; then
    if flux --context "$DEST_CLUSTER" resume ks -n flux-system velero; then
      VELERO_SUSPENDED=false
    else
      cleanup_exit_code=1
    fi
  fi

  return "$cleanup_exit_code"
}

handle_exit() {
  local exit_code=$?

  trap - EXIT
  set +e
  cleanup_velero_configuration
  exit "$exit_code"
}

#######################################################################################
### Verify cluster access
###
verify_cluster_access "$SOURCE_CLUSTER"
verify_cluster_access "$DEST_CLUSTER"

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

trap 'handle_exit' EXIT

flux --context "$DEST_CLUSTER" suspend ks -n flux-system velero
VELERO_SUSPENDED=true
wait_for_velero "BackupStorageLocation default"
kubectl --context "$DEST_CLUSTER" patch BackupStorageLocation default --namespace velero --type merge --patch "$PATCH_JSON"
BACKUP_LOCATION_PATCHED=true

echo ""
printf "Wait for backup \"%s\" to be available in destination cluster \"%s\" before we can restore..." "$BACKUP_NAME" "$DEST_CLUSTER"
BACKUP_AVAILABLE=false
for _ in {1..360}; do
  if velero --kubecontext "$DEST_CLUSTER" backup describe "$BACKUP_NAME" >/dev/null 2>&1; then
    BACKUP_AVAILABLE=true
    break
  fi
  printf "."
  sleep 5
done
if [[ $BACKUP_AVAILABLE != true ]]; then
  echo "ERROR: Backup \"$BACKUP_NAME\" was not available within 30 minutes." >&2
  velero --kubecontext "$DEST_CLUSTER" backup describe "$BACKUP_NAME" >&2 || true
  exit 1
fi
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
echo "$RESTORE_YAML" | kubectl --context "$DEST_CLUSTER" apply -f -

echo ""
echo "Wait for secrets to be restored..."
please_wait_for_restore_to_be_completed "secret"

#######################################################################################
### Restore configmaps
###

echo ""
echo "Restore app specific configmaps..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' <${WORKDIR_PATH}/restore_configmap.yaml)"
echo "$RESTORE_YAML" | kubectl --context "$DEST_CLUSTER" apply -f -

echo ""
echo "Wait for configmaps to be restored..."
please_wait_for_restore_to_be_completed "configmaps"

#######################################################################################
### Restore Radix Registration resources
###

echo ""
echo "Restore Radix Registration resources..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' <${WORKDIR_PATH}/restore_radix_rr.yaml)"
echo "$RESTORE_YAML" | kubectl --context "$DEST_CLUSTER" apply -f -

echo ""
echo "Wait for Radix registration resources to be restored..."
please_wait_for_restore_to_be_completed "radix-rr"

#######################################################################################
### Restore remaining Radix resources
###

echo ""
echo "Restore remaining Radix resources..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' <${WORKDIR_PATH}/restore_radix.yaml)"
echo "$RESTORE_YAML" | kubectl --context "$DEST_CLUSTER" apply -f -

echo ""
echo "Wait for remaining Radix resources to be restored..."
please_wait_for_restore_to_be_completed "radix"

#######################################################################################
### Configure velero back to normal operation in destination
###

echo ""
echo "Configure velero back to normal operation in destination..."

trap - EXIT
cleanup_velero_configuration

#######################################################################################
### Done!
###

echo ""
echo "All restore tasks are done!"

# Print restore status
echo "Run \"velero restore get\" to get latest status:"
velero --kubecontext "$DEST_CLUSTER" restore get

echo "Done restoring apps"
