#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Backup/Restore prometheus

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

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env SOURCE_CLUSTER="weekly-33" DEST_CLUSTER="weekly-34" ./prometheus-db-backup.sh

#######################################################################################
### START
###

echo ""
echo "Start Backup/Restore of Prometheus Database... "

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

hash velero 2>/dev/null || {
    echo -e "\nERROR: velero not found in PATH. Exiting..." >&2
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

if [[ -z "${RADIX_ZONE_ENV}" ]]; then
    echo "ERROR: Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "${RADIX_ZONE_ENV}" ]]; then
        echo "ERROR: RADIX_ZONE_ENV=${RADIX_ZONE_ENV} is invalid, the file does not exist." >&2
        exit 1
    fi
    source "${RADIX_ZONE_ENV}"
fi

if [[ -z "${SOURCE_CLUSTER}" ]]; then
    echo "ERROR: Please provide SOURCE_CLUSTER" >&2
    exit 1
fi

if [[ -z "${DEST_CLUSTER}" ]]; then
    echo "ERROR: Please provide DEST_CLUSTER" >&2
    exit 1
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

# Optional inputs

if [[ -z "${USER_PROMPT}" ]]; then
    USER_PROMPT=true
fi

# Script vars

BACKUP_NAME="prometheus-$(date '+%Y%m%d%H%M%S')"

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "${AZ_SUBSCRIPTION_ID}" >/dev/null
printf "Done.\n"

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

# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "${AZ_RESOURCE_GROUP_CLUSTERS}" "${SOURCE_CLUSTER}" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"${SOURCE_CLUSTER}\" not found." >&2
    exit 0
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###

verify_cluster_access

MONITOR_NAMESPACE="monitor"
PROMETHEUS_POD_NAME="prometheus-prometheus-operator-prometheus-0"

echo ""
printf "Waiting for Prometheus pod to be Ready..."
while [[ $(kubectl get pods ${PROMETHEUS_POD_NAME} --namespace ${MONITOR_NAMESPACE} --output 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
    printf "."
    sleep 5
done
printf "Done.\n"

if [ "$(kubectl exec ${PROMETHEUS_POD_NAME} --namespace ${MONITOR_NAMESPACE} --tty --stdin -- df /prometheus | grep / | awk '{print $5}' | sed 's/%//g' 2>&1)" -gt 50 ]; then
    echo "Unable to create backup on Prometheus. Check out the PVC to have 50% free for snapshots"
    exit 1
fi

printf "%s► Starting backup job %s\n" "${grn}" "${normal}"
SIZE=$(($(kubectl exec ${PROMETHEUS_POD_NAME} --tty --stdin --namespace ${MONITOR_NAMESPACE} -- du -d0 /prometheus | awk '{print $1}') / 1024 / 1024 + 10))
ESTIMATED_MOVE_DURATION_SECONDS=$((SIZE * 3600 / 225))

# Create disk
printf "%s► Create new 'Prometheus-Backup' disk with disksize %s GB %s\n" "${grn}" "${SIZE}" "${normal}"
NODE_RG=$(az aks show --resource-group "${AZ_RESOURCE_GROUP_CLUSTERS}" --name "${SOURCE_CLUSTER}" | jq -r ".nodeResourceGroup")
DISK_HANDLE=$(az disk create --resource-group "${NODE_RG}" --name "Prometheus-Backup" --size-gb "${SIZE}" --sku "StandardSSD_LRS" --location "${AZ_LOCATION}" --query id --output tsv)

# Create PV
YAML_PV_FILE="pv-prometheus-backup.yaml"
cat <<EOF | tee "${YAML_PV_FILE}" | kubectl apply --filename -
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/provisioned-by: disk.csi.azure.com
  name: pv-prometheus-backup
spec:
  capacity:
    storage: ${SIZE}Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: managed
  csi:
    driver: disk.csi.azure.com
    readOnly: false
    volumeHandle: ${DISK_HANDLE}
    volumeAttributes:
      fsType: ext4
EOF

# Create PVC
YAML_PVC_FILE="pvc-prometheus-backup.yaml"
cat <<EOF | tee "${YAML_PVC_FILE}" | kubectl apply --filename -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-prometheus-backup
  namespace: ${MONITOR_NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${SIZE}Gi
  volumeName: pv-prometheus-backup
  storageClassName: managed
EOF

flux suspend helmrelease kube-prometheus-stack --namespace ${MONITOR_NAMESPACE}

kubectl patch prometheus prometheus-operator-prometheus \
    --namespace ${MONITOR_NAMESPACE} \
    --type merge \
    --patch '{"spec":{"enableAdminAPI":true,"volumeMounts":[{"mountPath":"/backup","name":"backup"}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"pvc-prometheus-backup"}}]}}' # Enable Admin and Mount volumes

printf "Wait and check if backup folder are mounted in the operator..."
while [ "$(kubectl exec ${PROMETHEUS_POD_NAME} --namespace ${MONITOR_NAMESPACE} --tty --stdin -- test -d /backup 2>&1)" != "" ]; do
    printf "."
    sleep 5
done
printf "Done.\n"

printf "%s► Annotate Prometheus for -Backup commands...%s\n" "${grn}" "${normal}"
kubectl annotate pod/${PROMETHEUS_POD_NAME} \
    --namespace ${MONITOR_NAMESPACE} \
    pre.hook.backup.velero.io/command='["/bin/sh", "-c", "cat /dev/null > /backup/prometheusbackup.tar && tar -cf /backup/prometheusbackup.tar /prometheus/snapshots"]' # Prepare what to do in a Velero backup

kubectl annotate pod/${PROMETHEUS_POD_NAME} \
    --namespace ${MONITOR_NAMESPACE} \
    post.hook.backup.velero.io/command='["/bin/sh", "-c", "rm -rf /prometheus/snapshots && touch /backup/backupOK"]' # Prepare what to do after

kubectl annotate pod/${PROMETHEUS_POD_NAME} \
    --namespace ${MONITOR_NAMESPACE} \
    pre.hook.backup.velero.io/timeout=300m # Wait

#Create a job to make Prometheus snapshot on its own API
YAML_JOB_PROMETHEUS="prometheus-backup-job.yaml"
cat <<EOF | tee "${YAML_JOB_PROMETHEUS}" | kubectl apply --filename -
apiVersion: batch/v1
kind: Job
metadata:
  name: prometheus-backup
  namespace: ${MONITOR_NAMESPACE}
spec:
  template:
    metadata:
      name: prometheus-backup
    spec:
      containers:
      - name: backup
        image: curlimages/curl
        command:
        - curl
        - -XPOST
        - http://prometheus-operator-prometheus.${MONITOR_NAMESPACE}.svc:9090/api/v1/admin/tsdb/snapshot
      restartPolicy: OnFailure
EOF

rm --force $YAML_JOB_PROMETHEUS

printf "Waiting for the snapshot of Prometheus to be complete..."
while [ "$(kubectl get job prometheus-backup --namespace ${MONITOR_NAMESPACE} --output json | jq -r .status.conditions[].status 2>&1)" != "True" ]; do
    printf "."
    sleep 5
done
printf "Done.\n"

velero backup create "${BACKUP_NAME}" \
    --include-namespaces ${MONITOR_NAMESPACE} \
    --selector prometheus=prometheus-operator-prometheus \
    --exclude-resources pvc,pv \
    --storage-location azure

printf "Estimated restore time %02dh:%02dm:%02ds\n" $((ESTIMATED_MOVE_DURATION_SECONDS / 3600)) $((ESTIMATED_MOVE_DURATION_SECONDS % 3600 / 60)) $((ESTIMATED_MOVE_DURATION_SECONDS % 60))
printf "Waiting on Velero to complete Prometheus backup..."
while [ "$(kubectl get backup "${BACKUP_NAME}" --namespace "${VELERO_NAMESPACE}" --output json | jq -r ".status.phase" 2>&1)" != "Completed" ]; do
    printf "."
    sleep 5
done
printf "Done.\n"

kubectl patch prometheus prometheus-operator-prometheus \
    --namespace ${MONITOR_NAMESPACE} \
    --type merge \
    --patch '{"spec":{"enableAdminAPI":null,"volumeMounts":null,"volumes":null}}'

flux resume helmrelease kube-prometheus-stack --namespace ${MONITOR_NAMESPACE}

kubectl delete job prometheus-backup --namespace ${MONITOR_NAMESPACE} 2>/dev/null
kubectl delete pvc pvc-prometheus-backup --namespace ${MONITOR_NAMESPACE}
kubectl delete pv pv-prometheus-backup

#######################################################################################
### RESTORE
###

printf "%s► Starting restore job %s\n" "${grn}" "${normal}"

#Change to destination
echo "Connecting kubectl to destination..."
# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "${AZ_RESOURCE_GROUP_CLUSTERS}" "${DEST_CLUSTER}" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"${DEST_CLUSTER}\" not found." >&2
    exit 0
}
printf "...Done.\n"

kubectl apply --filename ${YAML_PV_FILE}
kubectl apply --filename ${YAML_PVC_FILE}

rm --force ${YAML_PV_FILE}
rm --force ${YAML_PVC_FILE}

flux suspend helmrelease kube-prometheus-stack --namespace ${MONITOR_NAMESPACE}

kubectl patch prometheus prometheus-operator-prometheus \
    --namespace ${MONITOR_NAMESPACE} \
    --type merge \
    --patch '{"spec":{"replicas":0}}'

kubectl apply --filename prometheus-restore-job.yaml

printf "Estimated restore time %02dh:%02dm:%02ds\n" $((ESTIMATED_MOVE_DURATION_SECONDS / 3600)) $((ESTIMATED_MOVE_DURATION_SECONDS % 3600 / 60)) $((ESTIMATED_MOVE_DURATION_SECONDS % 60))
printf "Waiting on Prometheus restore job to complete..."
while [ "$(kubectl get job prometheus-restore --namespace ${MONITOR_NAMESPACE} --output json | jq -r ".status.conditions[].status" 2>&1)" != "True" ]; do
    printf "."
    sleep 5
done
printf "Done.\n"

printf "%s► Cleaning up temporary resources %s\n" "${grn}" "${normal}"
kubectl patch pv pv-prometheus-backup \
    --type merge \
    --patch '{"spec":{"claimRef":null}}'

kubectl delete job prometheus-restore \
    --namespace ${MONITOR_NAMESPACE} 2>/dev/null

kubectl patch prometheus prometheus-operator-prometheus \
    --namespace ${MONITOR_NAMESPACE} \
    --type merge \
    --patch '{"spec":{"replicas":1}}'

kubectl patch pv pv-prometheus-backup \
    --type merge \
    --patch '{"spec":{"persistentVolumeReclaimPolicy": "Delete"}}'

kubectl delete pvc pvc-prometheus-backup \
    --namespace ${MONITOR_NAMESPACE}

echo ""
printf "%Prometheus Backup/Restore done!%s\n" "${grn}" "${normal}"
