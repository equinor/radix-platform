#!/usr/bin/env bash
#RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env SOURCE_CLUSTER="weekly-2" DEST_CLUSTER="weekly-3" ./prometheus-db-backup.sh
USER_PROMPT="true"

echo ""
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
    echo "ERROR: Please provide SOURCE_CLUSTER" >&2
    exit 1
fi

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$SOURCE_CLUSTER" || {
  # Send message to stderr
  echo -e "ERROR: Cluster \"$DEST_CLUSTER\" not found." >&2
  exit 0
}

if [ "$(kubectl exec --tty --stdin -n monitor prometheus-prometheus-operator-prometheus-0 -- df /prometheus | grep / | awk '{print $5}' | sed 's/%//g' 2>&1)" -gt 50 ] ; then
   echo "Unable to create backup on Prometheus. Check out the PVC to have 50% free for snapshots"
   exit 1

fi

printf "%s► Starting backup job "${normal}"\n"
SIZE=$(expr $((($(kubectl exec --tty --stdin -n monitor prometheus-prometheus-operator-prometheus-0 -- du -d0  /prometheus | awk '{print $1}') / 1024) / 1024 )) + 10)

#Create disk
NODE_RG=$(az aks show -g "$AZ_RESOURCE_GROUP_CLUSTERS" -n "$SOURCE_CLUSTER" | jq -r ."nodeResourceGroup")
printf "%s► Create new 'Prometheus-Backup' disk with disksize $SIZE GB\n"
DISK_HANDLE=$(az disk create --resource-group "$NODE_RG" --name "Prometheus-Backup" --size-gb "$SIZE" --sku "StandardSSD_LRS" --location "$AZ_LOCATION"  --query id --output tsv)

#Create PV
YAML_PV_FILE="pv-prometheus-backup.yaml"
echo "apiVersion: v1
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
    volumeHandle: $(echo $DISK_HANDLE)
    volumeAttributes:
      fsType: ext4
" > $YAML_PV_FILE
kubectl apply --filename $YAML_PV_FILE


#Create PVC
YAML_PVC_FILE="pvc-prometheus-backup.yaml"
echo "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-prometheus-backup
  namespace: monitor
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: ${SIZE}Gi
  volumeName: pv-prometheus-backup
  storageClassName: managed
" > $YAML_PVC_FILE
kubectl apply --filename $YAML_PVC_FILE
#rm -f $YAML_PVC_FILE

flux suspend hr -n monitor kube-prometheus-stack

kubectl -n monitor patch prometheus prometheus-operator-prometheus --type merge --patch '{"spec":{"enableAdminAPI":true,"volumeMounts":[{"mountPath":"/backup","name":"backup"}],"volumes":[{"name":"backup","persistentVolumeClaim":{"claimName":"pvc-prometheus-backup"}}]}}' # Enable Admin and Mount volumes

echo "Wait and check if backup folder are mounted in the operator..."
while [ "$(kubectl exec --tty --stdin -n monitor prometheus-prometheus-operator-prometheus-0 -- test -d /backup 2>&1)" != "" ]; do
    printf "."
    sleep 5
done
printf "Done.\n"

printf "%s► Annotate Prometheus for -Backup commands...\n"
kubectl -n monitor annotate pod/prometheus-prometheus-operator-prometheus-0 pre.hook.backup.velero.io/command='["/bin/sh", "-c", "cat /dev/null > /backup/prometheusbackup.tar && tar -cf /backup/prometheusbackup.tar /prometheus/snapshots"]' # Prepare what to do in a Velero backup
kubectl -n monitor annotate pod/prometheus-prometheus-operator-prometheus-0 post.hook.backup.velero.io/command='["/bin/sh", "-c", "rm -rf /prometheus/snapshots && touch /backup/backupOK"]' # Prepare what to do after
kubectl -n monitor annotate pod/prometheus-prometheus-operator-prometheus-0 pre.hook.backup.velero.io/timeout=300m # Wait


#Create a job to make Prometheus snapshot on its own API
YAML_JOB_PROMETHEUS="prometheus-backup-job.yaml"
echo "apiVersion: batch/v1
kind: Job
metadata:
  name: prometheus-backup
  namespace: monitor
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
        - http://prometheus-operator-prometheus.monitor.svc:9090/api/v1/admin/tsdb/snapshot
      restartPolicy: OnFailure
" > $YAML_JOB_PROMETHEUS
kubectl apply --filename $YAML_JOB_PROMETHEUS
rm -f $YAML_JOB_PROMETHEUS


echo "Waiting for for the snapshot of Prometheus to be complete..."
while [ "$(kubectl get job -n monitor prometheus-backup -ojson | jq -r .status.conditions[].status 2>&1)" != "True" ]; do
    printf "."
    sleep 5
done
printf "Done.\n"

BACKUP_NAME="prometheus-$(date '+%Y%m%d%H%M%S')"
velero backup create "$BACKUP_NAME" --include-namespaces monitor --selector prometheus=prometheus-operator-prometheus  --exclude-resources pvc,pv --storage-location azure

echo "Waiting for for Velero backup of Prometheus to disk to be complete..."
echo "Estimate calculation around $(echo "scale=2; $SIZE / 225" | bc) hours"
while [ "$(kubectl get backup -n velero  "$BACKUP_NAME" -ojson | jq -r .status.phase 2>&1)" != "Completed" ]; do
    printf "."
    sleep 5
done
printf "Done.\n"
kubectl -n monitor patch prometheus prometheus-operator-prometheus --type merge --patch '{"spec":{"enableAdminAPI":null,"volumeMounts":null,"volumes":null}}' # Remove volume
flux resume hr -n monitor kube-prometheus-stack
kubectl delete job -n monitor prometheus-backup 2> /dev/null
kubectl delete pvc -n monitor pvc-prometheus-backup
kubectl delete pv pv-prometheus-backup


###########################################################
# RESTORE
###########################################################
printf "%s► Starting restore job "${normal}""
#Change to destination

echo "Connecting kubectl to destination..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$DEST_CLUSTER" || {
  # Send message to stderr
  echo -e "ERROR: Cluster \"$DEST_CLUSTER\" not found." >&2
  exit 0
}
kubectl apply --filename $YAML_PV_FILE
kubectl apply --filename $YAML_PVC_FILE
rm -f $YAML_PV_FILE
rm -f $YAML_PVC_FILE

flux suspend hr -n monitor kube-prometheus-stack
kubectl -n monitor patch prometheus prometheus-operator-prometheus --type merge --patch '{"spec":{"replicas":0}}' 
kubectl apply --filename prometheus-restore-job.yaml

echo "Waiting for the restore job of Prometheus to be complete..."
echo "Estimate calculation around $(echo "scale=2; $SIZE / 225" | bc) hours"
while [ "$(kubectl get job -n monitor prometheus-restore -ojson | jq -r .status.conditions[].status 2>&1)" != "True" ]; do
    printf "."
    sleep 5
done
printf "Done.\n"

printf "%s► Cleaning up temporary resources \n"
kubectl patch pv pv-prometheus-backup --type merge --patch '{"spec":{"claimRef":null}}'
kubectl delete job -n monitor prometheus-restore 2> /dev/null
kubectl -n monitor patch prometheus prometheus-operator-prometheus --type merge --patch '{"spec":{"replicas":1}}'
kubectl patch pv pv-prometheus-backup --type merge --patch '{"spec":{"persistentVolumeReclaimPolicy": "Delete"}}'
kubectl delete pvc -n monitor pvc-prometheus-backup
