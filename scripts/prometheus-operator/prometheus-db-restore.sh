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
# - DEST_CLUSTER        : Cluster that will receive the restored Prometheus database
# - BACKUP_NAME         : For example "prometheus-backup-20260820143000"

# Optional:
# - USER_PROMPT         : Is human interaction required to run script? true/false. Default is true.
# - BACKUP_ZONE         : Zone containing the source storage account. Defaults to RADIX_ZONE.

#######################################################################################
### HOW TO USE
###

## Restore within one zone:
# RADIX_ZONE=dev BACKUP_CLUSTER="weekly-33" DEST_CLUSTER="weekly-34" BACKUP_NAME="prometheus-backup-20260820143000" ./prometheus-db-restore.sh

## Restore from Playground to Dev:
# RADIX_ZONE=dev BACKUP_ZONE=playground BACKUP_CLUSTER="playground-29" DEST_CLUSTER="weekly-34" BACKUP_NAME="prometheus-backup-20260825100000" ./prometheus-db-restore.sh
## Cross-zone requirement: radix-id-prometheus-backup-dev (the destination identity) needs
## Storage Blob Data Reader on the source account radixveleroplayground.
## The operator must have Owner or User Access Administrator permission on the source account.
## Cross-zone network requirement: the Dev hub VNet must resolve and reach the Playground Blob endpoint through Private Link.
## Create a private endpoint in the Dev hub VNet (run only if one does not already exist):
# SOURCE_STORAGE_ID=$(az storage account show --name radixveleroplayground --resource-group common-playground --query id --output tsv)
# az network private-endpoint create --resource-group cluster-vnet-hub-dev --name pe-radixveleroplayground-from-dev --vnet-name vnet-hub --subnet private-links --private-connection-resource-id "${SOURCE_STORAGE_ID}" --group-id blob --connection-name radixveleroplayground-from-dev
## Link the Blob Private DNS zone to the Dev hub VNet:
# az network private-endpoint dns-zone-group create --resource-group cluster-vnet-hub-dev --endpoint-name pe-radixveleroplayground-from-dev --name default --private-dns-zone privatelink.blob.core.windows.net
## Verify that the source storage account connection is approved:
# az network private-endpoint-connection list --id "${SOURCE_STORAGE_ID}" --query "[?properties.privateEndpoint.id && properties.privateLinkServiceConnectionState.status=='Approved'].{endpoint:properties.privateEndpoint.id,status:properties.privateLinkServiceConnectionState.status}" --output table
## Add the temporary permission before the restore:
# DEST_IDENTITY_PRINCIPAL_ID=$(az identity show --name radix-id-prometheus-backup-dev --resource-group common-dev --query principalId --output tsv)
# az role assignment create --assignee-object-id "${DEST_IDENTITY_PRINCIPAL_ID}" --assignee-principal-type ServicePrincipal --role "Storage Blob Data Reader" --scope "${SOURCE_STORAGE_ID}"
## Remove the permission after the restore:
# az role assignment delete --assignee-object-id "${DEST_IDENTITY_PRINCIPAL_ID}" --role "Storage Blob Data Reader" --scope "${SOURCE_STORAGE_ID}"

## Monitor the restore before starting it:
# kubectl --context "${DEST_CLUSTER}" get job prometheus-restore -n monitor -w
# kubectl --context "${DEST_CLUSTER}" logs -n monitor -l job-name=prometheus-restore --all-containers --prefix -f
# kubectl --context "${DEST_CLUSTER}" get pods -n monitor -l job-name=prometheus-restore -w
# kubectl --context "${DEST_CLUSTER}" exec -n monitor -l job-name=prometheus-restore -c azcopy -- du -sh /prometheus
# kubectl --context "${DEST_CLUSTER}" exec -n monitor -l job-name=prometheus-restore -c azcopy -- find /prometheus -type f | wc -l
# Use the actual Pod name if kubectl cannot select by label:
# kubectl --context "${DEST_CLUSTER}" get pods -n monitor -l job-name=prometheus-restore

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
    kubectl --context "${DEST_CLUSTER}" delete job prometheus-restore \
      --namespace "${MONITOR_NAMESPACE}" --ignore-not-found --wait=true
  fi

  if [[ ${PROMETHEUS_SCALED_DOWN} == true ]]; then
    kubectl --context "${DEST_CLUSTER}" patch prometheus "${PROMETHEUS_NAME}" \
      --namespace "${MONITOR_NAMESPACE}" \
      --type merge \
      --patch "{\"spec\":{\"replicas\":${ORIGINAL_PROMETHEUS_REPLICAS}}}"
  fi

  if [[ ${FLUX_SUSPENDED} == true ]]; then
    flux --context "${DEST_CLUSTER}" resume helmrelease kube-prometheus-stack \
      --namespace "${MONITOR_NAMESPACE}"
    flux --context "${DEST_CLUSTER}" reconcile helmrelease kube-prometheus-stack \
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

BACKUP_ZONE_EXPLICIT=false
if [[ -n "${BACKUP_ZONE:-}" ]]; then
  BACKUP_ZONE_EXPLICIT=true
fi
BACKUP_ZONE=${BACKUP_ZONE:-${RADIX_ZONE}}
if [[ ! ${BACKUP_ZONE} =~ ^(dev|playground|prod|c2|c3)$ ]]; then
  echo "ERROR: BACKUP_ZONE must be either dev|playground|prod|c2|c3" >&2
  exit 1
fi

for variable_name in BACKUP_CLUSTER DEST_CLUSTER BACKUP_NAME; do
  if [[ -z ${!variable_name-} ]]; then
        echo "ERROR: Please provide ${variable_name}" >&2
        exit 1
    fi
done

if [[ ! $BACKUP_NAME =~ ^prometheus-backup-[0-9]{14}$ ]]; then
    echo "ERROR: BACKUP_NAME must match prometheus-backup-YYYYMMDDHHMMSS" >&2
    exit 1
fi

USER_PROMPT=${USER_PROMPT:-true}

RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source "${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh"

function subscription_name() {
  local zone="$1"
  if [[ ${zone} == "dev" || ${zone} == "playground" ]]; then
    echo "s941"
  else
    echo "s940"
  fi
}

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
printf "\n%s► Read terraform variables and configuration%s\n" "${grn}" "${normal}"
RADIX_SUBSCRIPTION_NAME=$(subscription_name "${RADIX_ZONE}")
BACKUP_SUBSCRIPTION_NAME=$(subscription_name "${BACKUP_ZONE}")
RADIX_BASE_INFRASTRUCTURE_PATH="${RADIX_PLATFORM_REPOSITORY_PATH}/terraform/subscriptions/${RADIX_SUBSCRIPTION_NAME}/${RADIX_ZONE}/base-infrastructure"
BACKUP_BASE_INFRASTRUCTURE_PATH="${RADIX_PLATFORM_REPOSITORY_PATH}/terraform/subscriptions/${BACKUP_SUBSCRIPTION_NAME}/${BACKUP_ZONE}/base-infrastructure"
terraform -chdir="${RADIX_BASE_INFRASTRUCTURE_PATH}" init >&2
if [[ ${BACKUP_BASE_INFRASTRUCTURE_PATH} != "${RADIX_BASE_INFRASTRUCTURE_PATH}" ]]; then
  terraform -chdir="${BACKUP_BASE_INFRASTRUCTURE_PATH}" init >&2
fi
RADIX_ZONE_YAML=$(<"${RADIX_ZONE_ENV}")
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "${RADIX_ZONE_YAML}")
AZ_RADIX_ZONE_LOCATION=$(yq '.location' <<< "${RADIX_ZONE_YAML}")
RADIX_ENVIRONMENT=$(yq '.environment' <<< "${RADIX_ZONE_YAML}")
AZ_SUBSCRIPTION_NAME=$(yq '.subscription_shortname' <<< "${RADIX_ZONE_YAML}")
AZ_TENANT_ID=$(az account show --query tenantId --output tsv)
AZ_RESOURCE_GROUP_CLUSTERS=$(terraform -chdir="${RADIX_BASE_INFRASTRUCTURE_PATH}" output -raw az_resource_group_clusters)
AZ_RESOURCE_GROUP_COMMON=$(terraform -chdir="${RADIX_BASE_INFRASTRUCTURE_PATH}" output -raw az_resource_group_common)
AZ_BACKUP_STORAGE_ACCOUNT=$(terraform -chdir="${BACKUP_BASE_INFRASTRUCTURE_PATH}" output -raw velero_storage_account)
AZ_BACKUP_RESOURCE_GROUP_COMMON=$(terraform -chdir="${BACKUP_BASE_INFRASTRUCTURE_PATH}" output -raw az_resource_group_common)
PROMETHEUS_BACKUP_MI_CLIENT_ID=$(terraform -chdir="${RADIX_BASE_INFRASTRUCTURE_PATH}" output -raw radix_id_prometheus_backup_mi_client_id)
PROMETHEUS_BACKUP_MI_NAME="radix-id-prometheus-backup-${RADIX_ZONE}"

if [[ ${BACKUP_ZONE_EXPLICIT} == true && ${BACKUP_ZONE} != "${RADIX_ZONE}" ]]; then
  printf "\n%s Cross-zone restore requirements:%s\n" "${normal}" "${normal}"
  printf "%s Source zone: ${BACKUP_ZONE}; destination zone: ${RADIX_ZONE}.%s\n" "${normal}" "${normal}"
  printf "%s The destination managed identity must read the source Blob Storage account.%s\n" "${normal}" "${normal}"
  printf "%s The destination VNet must resolve and reach the source Blob endpoint through Private Link.%s\n" "${normal}" "${normal}"
  printf "%s Confirm that the source private endpoint is approved and its Private DNS zone is linked.%s\n" "${normal}" "${normal}"
  printf "%s Confirm that Storage Blob Data Reader is assigned to the destination identity on the source account.%s\n" "${normal}" "${normal}"
  printf "%s Optional commands to complete the task:%s\n" "${normal}" "${normal}"
  printf "%s # SOURCE_STORAGE_ID=\$(az storage account show --name ${AZ_BACKUP_STORAGE_ACCOUNT} --resource-group ${AZ_BACKUP_RESOURCE_GROUP_COMMON} --query id --output tsv)%s\n" "${grn}" "${normal}"
  printf "%s # az network private-endpoint create --resource-group cluster-vnet-hub-${RADIX_ZONE} --name pe-${AZ_BACKUP_STORAGE_ACCOUNT}-from-${RADIX_ZONE} --vnet-name vnet-hub --subnet private-links --private-connection-resource-id \"\${SOURCE_STORAGE_ID}\" --group-id blob --connection-name ${AZ_BACKUP_STORAGE_ACCOUNT}-from-${RADIX_ZONE}%s\n" "${grn}" "${normal}"
  printf "%s # az network private-endpoint dns-zone-group create --resource-group cluster-vnet-hub-${RADIX_ZONE} --endpoint-name pe-${AZ_BACKUP_STORAGE_ACCOUNT}-from-${RADIX_ZONE} --name default --private-dns-zone privatelink.blob.core.windows.net%s\n" "${grn}" "${normal}"
  printf "%s # az network private-endpoint-connection list --id \"\${SOURCE_STORAGE_ID}\" --query \"[?properties.privateEndpoint.id && properties.privateLinkServiceConnectionState.status=='Approved'].{endpoint:properties.privateEndpoint.id,status:properties.privateLinkServiceConnectionState.status}\" --output table%s\n" "${grn}" "${normal}"
  printf "%s # DEST_IDENTITY_PRINCIPAL_ID=\$(az identity show --name ${PROMETHEUS_BACKUP_MI_NAME} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --query principalId --output tsv)%s\n" "${grn}" "${normal}"
  printf "%s # az role assignment create --assignee-object-id \"\${DEST_IDENTITY_PRINCIPAL_ID}\" --assignee-principal-type ServicePrincipal --role \"Storage Blob Data Reader\" --scope \"\${SOURCE_STORAGE_ID}\"%s\n" "${grn}" "${normal}"
  if [[ ${USER_PROMPT} == true ]]; then
    read -r -p "Confirm that all cross-zone requirements are fulfilled? (y/n) " answer
    case ${answer} in
      [Yy]*) ;;
      *) echo "Quitting."; exit 0 ;;
    esac
  fi
fi

BLOB_NAMES=$(az storage blob list \
  --account-name "${AZ_BACKUP_STORAGE_ACCOUNT}" \
  --container-name "${BACKUP_CLUSTER}" \
  --prefix "${BACKUP_DATA_PREFIX}/" \
  --query '[].name' \
  --auth-mode login \
  --output tsv)
BACKUP_SNAPSHOT_BLOB_PREFIX=$(awk -F/ 'NF >= 4 && $3 ~ /^[0-9]{8}T[0-9]{6}Z-/ {print $1 "/" $2 "/" $3}' <<< "${BLOB_NAMES}" | sort -u | tail -1)
FLATTENED_SNAPSHOT_EXISTS=$(awk -F/ 'NF >= 3 && $3 != "manifest.json" && $3 !~ /^[0-9]{8}T[0-9]{6}Z-/ {found=1} END {if (found) print "true"}' <<< "${BLOB_NAMES}")
if [[ ${FLATTENED_SNAPSHOT_EXISTS} == "true" ]]; then
  RESTORE_BLOB_PREFIX="${BACKUP_DATA_PREFIX}"
  RESTORE_BLOB_LAYOUT="flattened"
elif [[ -n "${BACKUP_SNAPSHOT_BLOB_PREFIX}" ]]; then
  RESTORE_BLOB_PREFIX="${BACKUP_SNAPSHOT_BLOB_PREFIX}"
  RESTORE_BLOB_LAYOUT="legacy snapshot folder"
else
  echo "ERROR: No Prometheus snapshot files found under ${BACKUP_CLUSTER}/${BACKUP_DATA_PREFIX}." >&2
  exit 1
fi

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

printf "Checking that logged in AAD user is Owner of ${AZ_SUBSCRIPTION_ID} subscription... "
if ! az role assignment list \
  --scope "/subscriptions/${AZ_SUBSCRIPTION_ID}" \
  --assignee "$(az ad signed-in-user show --query id -o tsv)" \
  --include-inherited true \
  --query '[?roleDefinitionName==`Owner`].roleDefinitionName' \
  -o tsv | grep -qx 'Owner'; then
  echo -e "ERROR: Logged in user is not Owner of ${AZ_SUBSCRIPTION_ID} subscription. Owner access is required before assigning RBAC roles to the managed identity." >&2
  echo -e "Activate the subscription Owner role and re-run the script." >&2
  exit 1
else
  printf "Done.\n"
fi

echo ""
echo "Prometheus database restore will use the following configuration:"
echo "  RADIX_ZONE:                ${RADIX_ZONE}"
echo "  BACKUP_ZONE:               ${BACKUP_ZONE}"
echo "  BACKUP_CLUSTER:            ${BACKUP_CLUSTER}"
echo "  DEST_CLUSTER:              ${DEST_CLUSTER}"
echo "  BACKUP_NAME:               ${BACKUP_NAME}"
echo "  BACKUP_DATA:               ${BACKUP_CLUSTER}/${BACKUP_DATA_PREFIX}"
echo "  RESTORE_SOURCE:            ${BACKUP_CLUSTER}/${RESTORE_BLOB_PREFIX} (${RESTORE_BLOB_LAYOUT})"
echo "  AZ_BACKUP_STORAGE_ACCOUNT: ${AZ_BACKUP_STORAGE_ACCOUNT}"
echo ""

if [[ ${USER_PROMPT} == true ]]; then
    read -r -p "This replaces Prometheus data in ${DEST_CLUSTER}. Continue? (Y/n) " answer
    case ${answer} in
        ""|[Yy]*) ;;
        *) echo "Quitting."; exit 0 ;;
    esac
fi

printf "%s► Download and verify backup manifest %s\n" "${grn}" "${normal}"
printf "Downloading backup manifest... "
az storage blob download \
    --account-name "${AZ_BACKUP_STORAGE_ACCOUNT}" \
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
get_credentials "${AZ_RESOURCE_GROUP_CLUSTERS}" "${DEST_CLUSTER}" >/dev/null
verify_cluster_access "${DEST_CLUSTER}"

if [[ -n "${PROMETHEUS_BACKUP_MI_CLIENT_ID}" && "${PROMETHEUS_BACKUP_MI_CLIENT_ID}" != "null" ]]; then
    if ! kubectl --context "${DEST_CLUSTER}" get serviceaccount "${PROMETHEUS_BACKUP_UPLOADER_SERVICE_ACCOUNT}" \
        --namespace "${MONITOR_NAMESPACE}" >/dev/null 2>&1; then
        cat <<EOF | kubectl --context "${DEST_CLUSTER}" apply --filename -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${PROMETHEUS_BACKUP_UPLOADER_SERVICE_ACCOUNT}
  namespace: ${MONITOR_NAMESPACE}
EOF
    fi
    kubectl --context "${DEST_CLUSTER}" annotate serviceaccount "${PROMETHEUS_BACKUP_UPLOADER_SERVICE_ACCOUNT}" \
        --namespace "${MONITOR_NAMESPACE}" \
        "azure.workload.identity/client-id=${PROMETHEUS_BACKUP_MI_CLIENT_ID}" \
        --overwrite
fi

    PROMETHEUS_BACKUP_CONFIGURED_CLIENT_ID=$(kubectl --context "${DEST_CLUSTER}" \
      get serviceaccount "${PROMETHEUS_BACKUP_UPLOADER_SERVICE_ACCOUNT}" \
      --namespace "${MONITOR_NAMESPACE}" \
      --output json 2>/dev/null | jq -r '.metadata.annotations["azure.workload.identity/client-id"] // empty' || true)
    if [[ -z "${PROMETHEUS_BACKUP_MI_CLIENT_ID}" || "${PROMETHEUS_BACKUP_MI_CLIENT_ID}" == "null" || \
      ${PROMETHEUS_BACKUP_CONFIGURED_CLIENT_ID} != "${PROMETHEUS_BACKUP_MI_CLIENT_ID}" ]]; then
      echo "ERROR: Destination ServiceAccount ${MONITOR_NAMESPACE}/${PROMETHEUS_BACKUP_UPLOADER_SERVICE_ACCOUNT} is not configured with the destination managed identity." >&2
      echo "Expected client ID: ${PROMETHEUS_BACKUP_MI_CLIENT_ID:-missing}; configured: ${PROMETHEUS_BACKUP_CONFIGURED_CLIENT_ID:-missing}" >&2
      exit 1
    fi

PROMETHEUS_SECURITY_CONTEXT_JSON=$(kubectl --context "${DEST_CLUSTER}" get statefulset prometheus-prometheus-operator-prometheus \
  --namespace "${MONITOR_NAMESPACE}" --output json | jq -c '.spec.template.spec.securityContext')
PROMETHEUS_RUN_AS_USER=$(jq -r '.runAsUser // 1000' <<< "${PROMETHEUS_SECURITY_CONTEXT_JSON}")
PROMETHEUS_RUN_AS_GROUP=$(jq -r '.runAsGroup // 2000' <<< "${PROMETHEUS_SECURITY_CONTEXT_JSON}")
printf "Prometheus data will be owned by %s:%s\n" "${PROMETHEUS_RUN_AS_USER}" "${PROMETHEUS_RUN_AS_GROUP}"

printf "%s► Stop Prometheus %s\n" "${grn}" "${normal}"
ORIGINAL_PROMETHEUS_REPLICAS=$(kubectl --context "${DEST_CLUSTER}" get prometheus "${PROMETHEUS_NAME}" \
  --namespace "${MONITOR_NAMESPACE}" --output json | jq -r '.spec.replicas // 1')
flux --context "${DEST_CLUSTER}" suspend helmrelease kube-prometheus-stack --namespace "${MONITOR_NAMESPACE}"
FLUX_SUSPENDED=true
kubectl --context "${DEST_CLUSTER}" patch prometheus "${PROMETHEUS_NAME}" \
    --namespace "${MONITOR_NAMESPACE}" \
    --type merge \
    --patch '{"spec":{"replicas":0}}'
PROMETHEUS_SCALED_DOWN=true

printf "Waiting for Prometheus to stop..."
for _ in {1..60}; do
  if ! kubectl --context "${DEST_CLUSTER}" get pod "${PROMETHEUS_POD_NAME}" \
    --namespace "${MONITOR_NAMESPACE}" >/dev/null 2>&1; then
    break
  fi
  printf "."
  sleep 5
done
if kubectl --context "${DEST_CLUSTER}" get pod "${PROMETHEUS_POD_NAME}" \
  --namespace "${MONITOR_NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: Prometheus Pod did not stop; refusing to restore over its data PVC." >&2
  exit 1
fi
printf "Done.\n"

printf "%s► Restore Prometheus database directly from Blob Storage with AzCopy workload identity %s\n" "${grn}" "${normal}"
AZCOPY_BLOB_URL="https://${AZ_BACKUP_STORAGE_ACCOUNT}.blob.core.windows.net/${BACKUP_CLUSTER}/${RESTORE_BLOB_PREFIX}/*"
kubectl --context "${DEST_CLUSTER}" delete job prometheus-restore \
    --namespace "${MONITOR_NAMESPACE}" --ignore-not-found --wait=true
cat <<EOF | kubectl --context "${DEST_CLUSTER}" apply --filename -
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
              "\${AZCOPY_BIN}" copy "${AZCOPY_BLOB_URL}" /prometheus --recursive=true --exclude-pattern=manifest*.json
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
printf "Monitor the restore Job with:\n%skubectl logs -n monitor -l job-name=prometheus-restore --context %s --all-containers --prefix -f%s\n" "${grn}" "${DEST_CLUSTER}" "${normal}"

printf "Waiting for Prometheus restore job to complete..."
while true; do
    RESTORE_JOB_STATUS=$(kubectl --context "${DEST_CLUSTER}" get job prometheus-restore \
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
      kubectl --context "${DEST_CLUSTER}" logs job/prometheus-restore \
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

printf "Waiting for Prometheus to start after restore..."
for _ in {1..60}; do
  if [[ $(kubectl --context "${DEST_CLUSTER}" get pod "${PROMETHEUS_POD_NAME}" \
    --namespace "${MONITOR_NAMESPACE}" \
    --output 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' 2>/dev/null) == "True" ]]; then
    break
  fi
  printf "."
  sleep 5
done
if [[ $(kubectl --context "${DEST_CLUSTER}" get pod "${PROMETHEUS_POD_NAME}" \
  --namespace "${MONITOR_NAMESPACE}" \
  --output 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' 2>/dev/null) != "True" ]]; then
  echo "ERROR: Prometheus did not become Ready after restore." >&2
  exit 1
fi
printf "Done.\n"

if [[ ${BACKUP_ZONE_EXPLICIT} == true && ${BACKUP_ZONE} != "${RADIX_ZONE}" ]]; then
  printf "\n%s Optional cleanup commands after the restore:%s\n" "${grn}" "${normal}"
  printf "%s SOURCE_STORAGE_ID=\$(az storage account show --name ${AZ_BACKUP_STORAGE_ACCOUNT} --resource-group ${AZ_BACKUP_RESOURCE_GROUP_COMMON} --query id --output tsv)%s\n" "${grn}" "${normal}"
  printf "%s DEST_IDENTITY_PRINCIPAL_ID=\$(az identity show --name ${PROMETHEUS_BACKUP_MI_NAME} --resource-group ${AZ_RESOURCE_GROUP_COMMON} --query principalId --output tsv)%s\n" "${grn}" "${normal}"
  printf "%s az network private-endpoint dns-zone-group delete --resource-group cluster-vnet-hub-${RADIX_ZONE} --endpoint-name pe-${AZ_BACKUP_STORAGE_ACCOUNT}-from-${RADIX_ZONE} --name default%s\n" "${grn}" "${normal}"
  printf "%s az network private-endpoint delete --resource-group cluster-vnet-hub-${RADIX_ZONE} --name pe-${AZ_BACKUP_STORAGE_ACCOUNT}-from-${RADIX_ZONE}%s\n" "${grn}" "${normal}"
  printf "%s az role assignment delete --assignee-object-id \"\${DEST_IDENTITY_PRINCIPAL_ID}\" --role \"Storage Blob Data Reader\" --scope \"\${SOURCE_STORAGE_ID}\"%s\n" "${grn}" "${normal}"
fi

printf "%sPrometheus restore completed successfully.%s\n" "${grn}" "${normal}"