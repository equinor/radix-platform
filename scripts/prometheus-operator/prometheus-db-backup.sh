#!/usr/bin/env bash

set -Eeuo pipefail

#######################################################################################
### PURPOSE
###

# Create a durable Prometheus backup

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE          : dev|playground|prod|c2|c3
# - CLUSTER      : Ex: "test-2", "weekly-93"

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.
# - BACKUP_NAME         : Existing backup ID to continue as an incremental backup, Ex: "prometheus-backup-20260820143000".
#                         Omit to start a new backup with an automatic timestamp.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE=dev CLUSTER="weekly-33" ./prometheus-db-backup.sh

# Continue an existing backup incrementally:
# RADIX_ZONE=dev CLUSTER="weekly-33" BACKUP_NAME="prometheus-backup-20260820143000" ./prometheus-db-backup.sh

#######################################################################################
### START
###

echo ""
echo "Start Prometheus Database Backup... "

#######################################################################################
### Check for prerequisites binaries
###

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
gry=$'\e[2;37m'
normal=$(tput sgr0)

PROMETHEUS_PATCHED=false
FLUX_SUSPENDED=false

function cleanup_backup() {
    local exit_code=$?

    set +e
    printf "\n%s► Clean up temporary backup resources %s\n" "${grn}" "${normal}"

    if [[ ${PROMETHEUS_PATCHED} == true ]]; then
        kubectl --context "${CLUSTER}" patch prometheus prometheus-operator-prometheus \
            --namespace "${MONITOR_NAMESPACE}" \
            --type merge \
            --patch '{"spec":{"enableAdminAPI":null}}'

        printf "Waiting for Prometheus to be Ready after reverting admin API..."
        for _ in {1..60}; do
            if [[ $(kubectl --context "${CLUSTER}" get pod "${PROMETHEUS_POD_NAME}" \
                --namespace "${MONITOR_NAMESPACE}" \
                --output 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' 2>/dev/null) == "True" ]]; then
                break
            fi
            printf "."
            sleep 5
        done
        printf "\n"
    fi

    if [[ ${FLUX_SUSPENDED} == true ]]; then
        flux --context "${CLUSTER}" resume helmrelease kube-prometheus-stack \
            --namespace "${MONITOR_NAMESPACE}"
        flux --context "${CLUSTER}" reconcile helmrelease kube-prometheus-stack \
            --namespace "${MONITOR_NAMESPACE}"
    fi

    kubectl --context "${CLUSTER}" delete job prometheus-backup-upload \
        --namespace "${MONITOR_NAMESPACE}" --ignore-not-found

    return "${exit_code}"
}

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2
    exit 1
}

hash bc 2>/dev/null || {
    echo -e "\nERROR: bc not found in PATH. Exiting... " >&2
    exit 1
}

hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}

hash flux 2>/dev/null || {
    echo -e "\nERROR: flux not found in PATH. Exiting... " >&2
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

if [[ ${RADIX_ZONE:-} =~ ^(dev|playground|prod|c2|c3)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2|c3" >&2
    exit 1
fi

if [[ -z "${CLUSTER:-}" ]]; then
    echo "ERROR: Please provide CLUSTER" >&2
    exit 1
fi

# Source util scripts
RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

# Optional inputs

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
if [[ -z "${BACKUP_NAME:-}" ]]; then
    BACKUP_NAME="prometheus-backup-$(date '+%Y%m%d%H%M%S')"
    BACKUP_MODE="new"
else
    if [[ ! ${BACKUP_NAME} =~ ^prometheus-backup-[0-9]{14}$ ]]; then
        echo "ERROR: BACKUP_NAME must match prometheus-backup-YYYYMMDDHHMMSS" >&2
        exit 1
    fi
    BACKUP_MODE="incremental"
fi
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
AZ_RADIX_ZONE_LOCATION=$(yq '.location' <<< "$RADIX_ZONE_YAML")
RADIX_ENVIRONMENT=$(yq '.environment' <<< "$RADIX_ZONE_YAML")
AZ_SUBSCRIPTION_NAME=$(yq '.subscription_shortname' <<< "$RADIX_ZONE_YAML")
AZ_TENANT_ID=$(az account show --query tenantId --output tsv)
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")
AZ_VELERO_STORAGE_ACCOUNT=$(jq -r .velero_sa <<< "$RADIX_RESOURCE_JSON")
PROMETHEUS_BACKUP_MI_CLIENT_ID=$(jq -r .radix_id_prometheus_backup_mi_client_id <<< "$RADIX_RESOURCE_JSON")
BACKUP_CONTAINER="${CLUSTER}"
BACKUP_PREFIX="backups"
BACKUP_DATA_PREFIX="${BACKUP_PREFIX}/${BACKUP_NAME}"
MANIFEST_BLOB_NAME="${BACKUP_PREFIX}/${BACKUP_NAME}/manifest.json"
TMP_DIR=$(mktemp -d)
LOCAL_MANIFEST_FILE="${TMP_DIR}/${BACKUP_NAME}.manifest.json"

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "${AZ_SUBSCRIPTION_ID}" >/dev/null
printf "Done.\n"

#######################################################################################
### Verify Data Contributor role activation
###

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

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Prometheus db backup will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  AZ_RADIX_ZONE_LOCATION           : $AZ_RADIX_ZONE_LOCATION"
echo -e "   -  AZ_VELERO_STORAGE_ACCOUNT        : $AZ_VELERO_STORAGE_ACCOUNT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  CLUSTER                          : $CLUSTER"
echo -e "   -  BACKUP_NAME                      : $BACKUP_NAME"
echo -e "   -  BACKUP_MODE                      : $BACKUP_MODE"
echo -e "   -  BACKUP_DATA                      : ${BACKUP_CONTAINER}/${BACKUP_DATA_PREFIX}"
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

# Exit if cluster does not exist
printf "%s► Connect to cluster %s\n" "${grn}" "${normal}"
printf "Connecting kubectl..."
get_credentials "${AZ_RESOURCE_GROUP_CLUSTERS}" "${CLUSTER}" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"${CLUSTER}\" not found." >&2
    exit 0
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###

verify_cluster_access "${CLUSTER}"

MONITOR_NAMESPACE="monitor"
PROMETHEUS_BACKUP_UPLOADER_SERVICE_ACCOUNT="prometheus-backup-uploader"
PROMETHEUS_POD_NAME="prometheus-prometheus-operator-prometheus-0"
PROMETHEUS_PVC_NAME="prometheus-prometheus-operator-prometheus-db-prometheus-prometheus-operator-prometheus-0"

trap 'cleanup_backup; rm -rf "${TMP_DIR}"' EXIT

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

echo ""
printf "Waiting for Prometheus pod to be Ready..."
while [[ $(kubectl --context "${CLUSTER}" get pods ${PROMETHEUS_POD_NAME} --namespace ${MONITOR_NAMESPACE} --output 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    printf "."
    sleep 5
done
printf "Done.\n"

printf "%s► Enable Prometheus Admin API %s\n" "${grn}" "${normal}"
flux --context "${CLUSTER}" suspend helmrelease kube-prometheus-stack --namespace ${MONITOR_NAMESPACE}
FLUX_SUSPENDED=true

PROMETHEUS_POD_UID_BEFORE=$(kubectl --context "${CLUSTER}" get pod "${PROMETHEUS_POD_NAME}" \
    --namespace "${MONITOR_NAMESPACE}" --output 'jsonpath={.metadata.uid}' 2>/dev/null || true)

kubectl --context "${CLUSTER}" patch prometheus prometheus-operator-prometheus \
    --namespace ${MONITOR_NAMESPACE} \
    --type merge \
    --patch '{"spec":{"enableAdminAPI":true}}' # Enable Admin API to allow TSDB snapshots
PROMETHEUS_PATCHED=true

printf "Waiting for Prometheus to be replaced and ready with admin API enabled..."
while true; do
    PROMETHEUS_POD_UID_AFTER=$(kubectl --context "${CLUSTER}" get pod "${PROMETHEUS_POD_NAME}" \
        --namespace "${MONITOR_NAMESPACE}" --output 'jsonpath={.metadata.uid}' 2>/dev/null || true)
    PROMETHEUS_READY=$(kubectl --context "${CLUSTER}" get pod "${PROMETHEUS_POD_NAME}" \
        --namespace "${MONITOR_NAMESPACE}" \
        --output 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
    if [[ -n ${PROMETHEUS_POD_UID_AFTER} && ${PROMETHEUS_POD_UID_AFTER} != "${PROMETHEUS_POD_UID_BEFORE}" && ${PROMETHEUS_READY} == "True" ]]; then
        break
    fi
    printf "."
    sleep 5
done
printf "Done.\n"

PROMETHEUS_NODE_NAME=$(kubectl --context "${CLUSTER}" get pod "${PROMETHEUS_POD_NAME}" \
    --namespace "${MONITOR_NAMESPACE}" --output 'jsonpath={.spec.nodeName}')

printf "%s► Create Prometheus TSDB snapshot and sync to Blob Storage with AzCopy workload identity (%s backup) %s\n" "${grn}" "${BACKUP_MODE}" "${normal}"
AZCOPY_BLOB_URL="https://${AZ_VELERO_STORAGE_ACCOUNT}.blob.core.windows.net/${BACKUP_CONTAINER}/${BACKUP_DATA_PREFIX}"
kubectl --context "${CLUSTER}" delete job prometheus-backup-upload \
        --namespace "${MONITOR_NAMESPACE}" --ignore-not-found --wait=true
cat <<EOF | kubectl --context "${CLUSTER}" apply --filename -
apiVersion: batch/v1
kind: Job
metadata:
  name: prometheus-backup-upload
  namespace: ${MONITOR_NAMESPACE}
spec:
  backoffLimit: 0
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
    spec:
      nodeName: ${PROMETHEUS_NODE_NAME}
      serviceAccountName: ${PROMETHEUS_BACKUP_UPLOADER_SERVICE_ACCOUNT}
      restartPolicy: Never
      initContainers:
        - name: trigger-snapshot
          image: curlimages/curl
          command:
            - curl
            - -sf
            - --retry
            - "10"
            - --retry-delay
            - "5"
            - --retry-connrefused
            - -XPOST
            - http://prometheus-operator-prometheus.${MONITOR_NAMESPACE}.svc:9090/api/v1/admin/tsdb/snapshot
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
              if [ -z "\$(ls -A /prometheus/snapshots 2>/dev/null)" ]; then
                echo "ERROR: /prometheus/snapshots is missing or empty; snapshot trigger did not produce data." >&2
                exit 1
              fi
              tdnf install -y tar gawk >/dev/null
              case "\$(uname -m)" in
                x86_64) AZCOPY_URL=https://aka.ms/downloadazcopy-v10-linux ;;
                aarch64) AZCOPY_URL=https://aka.ms/downloadazcopy-v10-linux-arm64 ;;
                *) echo "ERROR: Unsupported architecture: \$(uname -m)" >&2; exit 1 ;;
              esac
              curl -sL "\${AZCOPY_URL}" -o /tmp/azcopy.tar.gz
              tar -xzf /tmp/azcopy.tar.gz -C /tmp
              AZCOPY_BIN=\$(find /tmp -maxdepth 1 -type d -name 'azcopy_linux_*')/azcopy
              SOURCE_SIZE=\$(du -sh /prometheus/snapshots | awk '{print \$1}')
              echo "Syncing snapshot (\${SOURCE_SIZE}) directly to Blob Storage..."
              "\${AZCOPY_BIN}" sync /prometheus/snapshots "${AZCOPY_BLOB_URL}" --delete-destination=false
              echo "TOTAL_SIZE_BYTES=\$(du -sb /prometheus/snapshots | awk '{print \$1}')"
              echo "FILE_COUNT=\$(find /prometheus/snapshots -type f | wc -l)"
              rm -rf /prometheus/snapshots
          volumeMounts:
            - name: prometheus-data
              mountPath: /prometheus
              subPath: prometheus-db
      volumes:
        - name: prometheus-data
          persistentVolumeClaim:
            claimName: ${PROMETHEUS_PVC_NAME}
EOF
printf "Waiting for AzCopy sync Job..."
while true; do
        AZCOPY_JOB_STATUS=$(kubectl --context "${CLUSTER}" get job prometheus-backup-upload \
                --namespace "${MONITOR_NAMESPACE}" --output json | jq -r '
                        if any(.status.conditions[]?; .type == "Complete" and .status == "True") then
                                "Complete"
                        elif any(.status.conditions[]?; .type == "Failed" and .status == "True") then
                                "Failed"
                        else
                                "Running"
                        end')
        if [[ ${AZCOPY_JOB_STATUS} == "Complete" ]]; then
                break
        fi
        if [[ ${AZCOPY_JOB_STATUS} == "Failed" ]]; then
                echo "ERROR: AzCopy sync Job failed." >&2
                kubectl --context "${CLUSTER}" logs job/prometheus-backup-upload \
                        --namespace "${MONITOR_NAMESPACE}" --all-containers=true >&2
                exit 1
        fi
        printf "."
        sleep 5
done
printf "Done.\n"

AZCOPY_LOGS=$(kubectl --context "${CLUSTER}" logs job/prometheus-backup-upload \
        --namespace "${MONITOR_NAMESPACE}" --container azcopy)
TOTAL_SIZE_BYTES=$(grep -oE 'TOTAL_SIZE_BYTES=[0-9]+' <<< "${AZCOPY_LOGS}" | tail -1 | cut -d= -f2)
FILE_COUNT=$(grep -oE 'FILE_COUNT=[0-9]+' <<< "${AZCOPY_LOGS}" | tail -1 | cut -d= -f2)
if [[ -z ${FILE_COUNT} || ${FILE_COUNT} -eq 0 ]]; then
    echo "ERROR: AzCopy synced zero files; refusing to record an empty backup." >&2
    echo "${AZCOPY_LOGS}" >&2
    exit 1
fi
jq -n \
    --arg backup_name "${BACKUP_NAME}" \
    --arg backup_mode "${BACKUP_MODE}" \
    --arg source_cluster "${CLUSTER}" \
    --arg storage_account "${AZ_VELERO_STORAGE_ACCOUNT}" \
    --arg container "${BACKUP_CONTAINER}" \
    --arg blob "${BACKUP_DATA_PREFIX}" \
    --arg updated_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --argjson total_size_bytes "${TOTAL_SIZE_BYTES}" \
    --argjson file_count "${FILE_COUNT}" \
    '{backup_name: $backup_name, backup_mode: $backup_mode, source_cluster: $source_cluster, storage_account: $storage_account, container: $container, blob: $blob, total_size_bytes: $total_size_bytes, file_count: $file_count, updated_at: $updated_at}' \
    > "${LOCAL_MANIFEST_FILE}"

printf "%s► Upload backup manifest to %s/%s %s\n" "${grn}" "${BACKUP_CONTAINER}" "${MANIFEST_BLOB_NAME}" "${normal}"
az storage container show \
    --name "${BACKUP_CONTAINER}" \
    --account-name "${AZ_VELERO_STORAGE_ACCOUNT}" \
    --auth-mode login \
    --only-show-errors > /dev/null
az storage blob upload \
    --account-name "${AZ_VELERO_STORAGE_ACCOUNT}" \
    --container-name "${BACKUP_CONTAINER}" \
    --name "${MANIFEST_BLOB_NAME}" \
    --file "${LOCAL_MANIFEST_FILE}" \
    --auth-mode login \
    --overwrite true \
    --only-show-errors > /dev/null
printf "Done.\n"

cleanup_backup
trap - EXIT
rm -rf "${TMP_DIR}"

echo ""
printf "%sPrometheus Backup done!%s\n" "${grn}" "${normal}"
printf "BACKUP_NAME=%s (pass this to continue as an incremental backup)\n" "${BACKUP_NAME}"
