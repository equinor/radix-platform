#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Restore a durable Prometheus backup into a cluster

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE          : dev|playground|prod|c2|c3
# - BACKUP_CLUSTER      : Blob container that contains the backup, for example "weekly-33"
# - CLUSTER             : Cluster that will receive the restored Prometheus database
# - BACKUP_NAME         : For example "prometheus-backup-20260820143000"

# Optional:
# - USER_PROMPT         : Is human interaction required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE=dev BACKUP_CLUSTER="weekly-33" CLUSTER="weekly-34" \
# BACKUP_NAME="prometheus-backup-20260820143000" ./prometheus-db-restore.sh

#######################################################################################
### START
###

set -Eeuo pipefail

echo ""
echo "Start Prometheus Database Restore..."

red=$'\e[1;31m'
grn=$'\e[1;32m'
gry=$'\e[2;37m'
normal=$(tput sgr0)

RESTORE_JOB_CREATED=false
PROMETHEUS_SCALED_DOWN=false
FLUX_SUSPENDED=false
ORIGINAL_PROMETHEUS_REPLICAS=1
PROMETHEUS_POD_NAME="prometheus-prometheus-operator-prometheus-0"

function cleanup_restore() {
  local exit_code=$?

  set +e
  printf "\n%s► Clean up temporary restore resources %s\n" "${grn}" "${normal}"

  if [[ ${RESTORE_JOB_CREATED} == true ]]; then
    kubectl --context "${CLUSTER}" delete job prometheus-restore \
      --namespace "${MONITOR_NAMESPACE}" --ignore-not-found --wait=true
  fi

  if [[ ${PROMETHEUS_SCALED_DOWN} == true ]]; then
    kubectl --context "${CLUSTER}" patch prometheus "${PROMETHEUS_NAME}" \
      --namespace "${MONITOR_NAMESPACE}" \
      --type merge \
      --patch "{\"spec\":{\"replicas\":${ORIGINAL_PROMETHEUS_REPLICAS}}}"
  fi

  if [[ ${FLUX_SUSPENDED} == true ]]; then
    flux --context "${CLUSTER}" resume helmrelease kube-prometheus-stack \
      --namespace "${MONITOR_NAMESPACE}"
    flux --context "${CLUSTER}" reconcile helmrelease kube-prometheus-stack \
      --namespace "${MONITOR_NAMESPACE}"
  fi

  return "${exit_code}"
}

printf "\nCheck for neccesary executables... "
for binary in az jq kubectl flux kubelogin yq; do
    hash "${binary}" 2>/dev/null || {
        echo -e "\nERROR: ${binary} not found in PATH. Exiting..." >&2
        exit 1
    }
done
printf "Done.\n"

if [[ ! ${RADIX_ZONE:-} =~ ^(dev|playground|prod|c2|c3)$ ]]; then
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2|c3" >&2
    exit 1
fi

for variable_name in BACKUP_CLUSTER CLUSTER BACKUP_NAME; do
  if [[ -z ${!variable_name-} ]]; then
        echo "ERROR: Please provide ${variable_name}" >&2
        exit 1
    fi
done

if [[ ! $BACKUP_NAME =~ ^prometheus-backup-[0-9]{14}$ ]]; then
    echo "ERROR: BACKUP_NAME must match prometheus-backup-YYYYMMDDHHMMSS" >&2
    exit 1
fi

RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source "${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh"

USER_PROMPT=${USER_PROMPT:-true}
MONITOR_NAMESPACE="monitor"
PROMETHEUS_NAME="prometheus-operator-prometheus"
PROMETHEUS_BACKUP_UPLOADER_SERVICE_ACCOUNT="prometheus-backup-uploader"
PROMETHEUS_PVC_NAME="prometheus-prometheus-operator-prometheus-db-prometheus-prometheus-operator-prometheus-0"
BACKUP_PREFIX="backups"
BACKUP_DATA_PREFIX="${BACKUP_PREFIX}/${BACKUP_NAME}"
MANIFEST_BLOB_NAME="${BACKUP_PREFIX}/${BACKUP_NAME}/manifest.json"
TMP_DIR=$(mktemp -d)
LOCAL_MANIFEST_FILE="${TMP_DIR}/${BACKUP_NAME}.manifest.json"

printf "\n%s► Read YAML configfile %s" "${grn}" "${RADIX_ZONE}"
RADIX_ZONE_ENV=$(config_path "${RADIX_ZONE}")
printf "\n%s► Read terraform variables and configuration%s" "${grn}" "${normal}"
RADIX_RESOURCE_JSON=$(environment_json "${RADIX_ZONE}")
RADIX_ZONE_YAML=$(<"${RADIX_ZONE_ENV}")
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "${RADIX_ZONE_YAML}")
AZ_RADIX_ZONE_LOCATION=$(yq '.location' <<< "${RADIX_ZONE_YAML}")
RADIX_ENVIRONMENT=$(yq '.environment' <<< "${RADIX_ZONE_YAML}")
AZ_SUBSCRIPTION_NAME=$(yq '.subscription_shortname' <<< "${RADIX_ZONE_YAML}")
AZ_TENANT_ID=$(az account show --query tenantId --output tsv)
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "${RADIX_RESOURCE_JSON}")
AZ_VELERO_STORAGE_ACCOUNT=$(jq -r .velero_sa <<< "${RADIX_RESOURCE_JSON}")
PROMETHEUS_BACKUP_MI_CLIENT_ID=$(jq -r .radix_id_prometheus_backup_mi_client_id <<< "${RADIX_RESOURCE_JSON}")

trap 'cleanup_restore; rm -rf "${TMP_DIR}"' EXIT

printf "\nLogging in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "${AZ_SUBSCRIPTION_ID}" >/dev/null
printf "Done.\n"

printf "Verifying that logged in AAD user has Radix Confidential Data Contributor on scope of ${AZ_SUBSCRIPTION_ID}... "
if ! az role assignment list \
  --scope "/subscriptions/${AZ_SUBSCRIPTION_ID}" \
  --assignee "$(az ad signed-in-user show --query id -o tsv)" \
  --query '[].roleDefinitionName' \
  -o tsv | grep -E '^Radix Confidential Data Contributor$'; then
  echo -e "ERROR: Logged in user is not Radix Confidential Data Contributor on scope of ${AZ_SUBSCRIPTION_ID} subscription. Is Azure resource activated?" >&2
  echo -e "Make sure you have enabled AZ PIM RADIX Cluster Admin - ${RADIX_ENVIRONMENT} role" >&2
  exit 1
fi
printf "Done.\n"

PIM_GROUP_NAME="AZ PIM RADIX Cluster Admin - ${AZ_SUBSCRIPTION_NAME}"
printf "Checking that ${PIM_GROUP_NAME} is active... "
if ! az ad group member check \
  --group "${PIM_GROUP_NAME}" \
  --member-id "$(az ad signed-in-user show --query id -o tsv)" \
  --query value \
  -o tsv 2>/dev/null | grep -qx true; then
  echo -e "" >&2
  printf "%s► Activate %s in Azure PIM and re-run the script.%s\n" "${red}" "${PIM_GROUP_NAME}" "${normal}" >&2
  exit 1
else
  printf "Done.\n"
fi

echo ""
echo "Prometheus database restore will use the following configuration:"
echo "  RADIX_ZONE: ${RADIX_ZONE}"
echo "  BACKUP_CLUSTER: ${BACKUP_CLUSTER}"
echo "  CLUSTER: ${CLUSTER}"
echo "  BACKUP_NAME: ${BACKUP_NAME}"
echo "  BACKUP_DATA: ${BACKUP_CLUSTER}/${BACKUP_DATA_PREFIX}"
echo "  AZ_VELERO_STORAGE_ACCOUNT: ${AZ_VELERO_STORAGE_ACCOUNT}"
echo ""

if [[ ${USER_PROMPT} == true ]]; then
    read -r -p "This replaces Prometheus data in ${CLUSTER}. Continue? (Y/n) " answer
    case ${answer} in
        ""|[Yy]*) ;;
        *) echo "Quitting."; exit 0 ;;
    esac
fi

printf "%s► Download and verify backup manifest %s\n" "${grn}" "${normal}"
printf "Downloading backup manifest... "
az storage blob download \
    --account-name "${AZ_VELERO_STORAGE_ACCOUNT}" \
    --container-name "${BACKUP_CLUSTER}" \
    --name "${MANIFEST_BLOB_NAME}" \
    --file "${LOCAL_MANIFEST_FILE}" \
    --auth-mode login \
    --only-show-errors > /dev/null
printf "Done.\n"

MANIFEST_BACKUP_NAME=$(jq -r .backup_name "${LOCAL_MANIFEST_FILE}")
MANIFEST_BACKUP_CLUSTER=$(jq -r .source_cluster "${LOCAL_MANIFEST_FILE}")
MANIFEST_FILE_COUNT=$(jq -r .file_count "${LOCAL_MANIFEST_FILE}")
MANIFEST_TOTAL_SIZE_BYTES=$(jq -r .total_size_bytes "${LOCAL_MANIFEST_FILE}")

if [[ ${MANIFEST_BACKUP_NAME} != "${BACKUP_NAME}" || ${MANIFEST_BACKUP_CLUSTER} != "${BACKUP_CLUSTER}" || ! ${MANIFEST_FILE_COUNT} =~ ^[0-9]+$ ]]; then
    echo "ERROR: Backup manifest does not match the requested backup." >&2
    exit 1
fi
printf "Manifest reports %s files, %s bytes.\n" "${MANIFEST_FILE_COUNT}" "${MANIFEST_TOTAL_SIZE_BYTES}"

printf "%s► Connect to cluster %s\n" "${grn}" "${normal}"
get_credentials "${AZ_RESOURCE_GROUP_CLUSTERS}" "${CLUSTER}" >/dev/null
verify_cluster_access "${CLUSTER}"

if [[ -n "${PROMETHEUS_BACKUP_MI_CLIENT_ID}" && "${PROMETHEUS_BACKUP_MI_CLIENT_ID}" != "null" ]]; then
    if ! kubectl --context "${CLUSTER}" get serviceaccount "${PROMETHEUS_BACKUP_UPLOADER_SERVICE_ACCOUNT}" \
        --namespace "${MONITOR_NAMESPACE}" >/dev/null 2>&1; then
        cat <<EOF | kubectl --context "${CLUSTER}" apply --filename -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${PROMETHEUS_BACKUP_UPLOADER_SERVICE_ACCOUNT}
  namespace: ${MONITOR_NAMESPACE}
EOF
    fi
    kubectl --context "${CLUSTER}" annotate serviceaccount "${PROMETHEUS_BACKUP_UPLOADER_SERVICE_ACCOUNT}" \
        --namespace "${MONITOR_NAMESPACE}" \
        "azure.workload.identity/client-id=${PROMETHEUS_BACKUP_MI_CLIENT_ID}" \
        --overwrite
fi

PROMETHEUS_SECURITY_CONTEXT_JSON=$(kubectl --context "${CLUSTER}" get statefulset prometheus-prometheus-operator-prometheus \
  --namespace "${MONITOR_NAMESPACE}" --output json | jq -c '.spec.template.spec.securityContext')
PROMETHEUS_RUN_AS_USER=$(jq -r '.runAsUser // 1000' <<< "${PROMETHEUS_SECURITY_CONTEXT_JSON}")
PROMETHEUS_RUN_AS_GROUP=$(jq -r '.runAsGroup // 2000' <<< "${PROMETHEUS_SECURITY_CONTEXT_JSON}")
printf "Prometheus data will be owned by %s:%s\n" "${PROMETHEUS_RUN_AS_USER}" "${PROMETHEUS_RUN_AS_GROUP}"

printf "%s► Stop Prometheus %s\n" "${grn}" "${normal}"
ORIGINAL_PROMETHEUS_REPLICAS=$(kubectl --context "${CLUSTER}" get prometheus "${PROMETHEUS_NAME}" \
  --namespace "${MONITOR_NAMESPACE}" --output json | jq -r '.spec.replicas // 1')
flux --context "${CLUSTER}" suspend helmrelease kube-prometheus-stack --namespace "${MONITOR_NAMESPACE}"
FLUX_SUSPENDED=true
kubectl --context "${CLUSTER}" patch prometheus "${PROMETHEUS_NAME}" \
    --namespace "${MONITOR_NAMESPACE}" \
    --type merge \
    --patch '{"spec":{"replicas":0}}'
PROMETHEUS_SCALED_DOWN=true

printf "Waiting for Prometheus to stop..."
for _ in {1..60}; do
  if ! kubectl --context "${CLUSTER}" get pod "${PROMETHEUS_POD_NAME}" \
    --namespace "${MONITOR_NAMESPACE}" >/dev/null 2>&1; then
    break
  fi
  printf "."
  sleep 5
done
if kubectl --context "${CLUSTER}" get pod "${PROMETHEUS_POD_NAME}" \
  --namespace "${MONITOR_NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: Prometheus Pod did not stop; refusing to restore over its data PVC." >&2
  exit 1
fi
printf "Done.\n"

printf "%s► Restore Prometheus database directly from Blob Storage with AzCopy workload identity %s\n" "${grn}" "${normal}"
AZCOPY_BLOB_URL="https://${AZ_VELERO_STORAGE_ACCOUNT}.blob.core.windows.net/${BACKUP_CLUSTER}/${BACKUP_DATA_PREFIX}"
kubectl --context "${CLUSTER}" delete job prometheus-restore \
    --namespace "${MONITOR_NAMESPACE}" --ignore-not-found --wait=true
cat <<EOF | kubectl --context "${CLUSTER}" apply --filename -
apiVersion: batch/v1
kind: Job
metadata:
  name: prometheus-restore
  namespace: ${MONITOR_NAMESPACE}
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: ${PROMETHEUS_BACKUP_UPLOADER_SERVICE_ACCOUNT}
      restartPolicy: Never
      containers:
        - name: azcopy
          image: mcr.microsoft.com/azure-cli:latest
          env:
            - name: AZCOPY_AUTO_LOGIN_TYPE
              value: WORKLOAD
            - name: AZCOPY_TENANT_ID
              value: ${AZ_TENANT_ID}
            - name: AZCOPY_CLIENT_ID
              value: ${PROMETHEUS_BACKUP_MI_CLIENT_ID}
          command:
            - sh
            - -c
            - |
              set -e
              tdnf install -y tar gawk >/dev/null
              case "\$(uname -m)" in
                x86_64) AZCOPY_URL=https://aka.ms/downloadazcopy-v10-linux ;;
                aarch64) AZCOPY_URL=https://aka.ms/downloadazcopy-v10-linux-arm64 ;;
                *) echo "ERROR: Unsupported architecture: \$(uname -m)" >&2; exit 1 ;;
              esac
              curl -sL "\${AZCOPY_URL}" -o /tmp/azcopy.tar.gz
              tar -xzf /tmp/azcopy.tar.gz -C /tmp
              AZCOPY_BIN=\$(find /tmp -maxdepth 1 -type d -name 'azcopy_linux_*')/azcopy
              echo "Removing old Prometheus data..."
              find /prometheus -mindepth 1 -delete
              echo "Copying backup files from Blob Storage..."
              "\${AZCOPY_BIN}" copy "${AZCOPY_BLOB_URL}/*" /prometheus --recursive=true
              if [ -z "\$(find /prometheus -type f -print -quit)" ]; then
                echo "ERROR: Restore produced no files in /prometheus." >&2
                exit 1
              fi
              echo "Correcting file ownership..."
              chown -R ${PROMETHEUS_RUN_AS_USER}:${PROMETHEUS_RUN_AS_GROUP} /prometheus
              echo "FILE_COUNT=\$(find /prometheus -type f | wc -l)"
          volumeMounts:
            - name: prometheus-data
              mountPath: /prometheus
              subPath: prometheus-db
      volumes:
        - name: prometheus-data
          persistentVolumeClaim:
            claimName: ${PROMETHEUS_PVC_NAME}
EOF
RESTORE_JOB_CREATED=true

printf "Waiting for Prometheus restore job to complete..."
while true; do
    RESTORE_JOB_STATUS=$(kubectl --context "${CLUSTER}" get job prometheus-restore \
      --namespace "${MONITOR_NAMESPACE}" --output json | jq -r '
        if any(.status.conditions[]?; .type == "Complete" and .status == "True") then
          "Complete"
        elif any(.status.conditions[]?; .type == "Failed" and .status == "True") then
          "Failed"
        else
          "Running"
        end')
    if [[ ${RESTORE_JOB_STATUS} == "Complete" ]]; then
      break
    fi
    if [[ ${RESTORE_JOB_STATUS} == "Failed" ]]; then
      echo "ERROR: Prometheus restore job failed." >&2
      kubectl --context "${CLUSTER}" logs job/prometheus-restore \
        --namespace "${MONITOR_NAMESPACE}" --all-containers=true >&2
      exit 1
    fi
    printf "."
    sleep 5
done
printf "Done.\n"

cleanup_restore
trap - EXIT
rm -rf "${TMP_DIR}"

printf "%sPrometheus restore completed successfully.%s\n" "${grn}" "${normal}"