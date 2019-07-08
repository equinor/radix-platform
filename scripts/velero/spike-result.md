# Spike: Velero

## Background

28 June, 2019 - Can we use Velero for disaster/recovery?  

## Purpose

 * Disaster Recovery
Sudden loss of cluster, all config and persisted data. Goal is to restore Radix platform itself as well as running applications with minimal downtime and user intervention.
 * Planned migration
Need to move configuration and persistent data from one healthy cluster to another with minimal downtime. We want to use Planned migration to also reduce configuration drift.

 * Possible other use-cases
Clone a cluster and do a test-upgrade on the shadow cluster.
Snapshot before in-place upgrade. Provides a possible way of roll-back in case of problems after upgrade.

#### Constraints/limitations

We do not support cross-cloud DR since that would involve transporting backups to a different cloud vendor causing all kinds of new challenges.

DR: User secrets cannot be backed up long term without consent. 
Migration: We cannot guarantee that software is not re-built and re-deployed and may also run different versions simultaneously on both clusters for a short period. Secrets: Problem: Velero cannot back up locally, only to remote storage. Is this acceptable even if remote storage is deleted once migration is complete?


## Tools

velero - (previously heptio ark, bought by vmware) - version 1.0.0 released in may 2019.
https://github.com/pieterlange/kube-backup (not updated since feb. 22 2019) - Dumps all K8s objects to git. Optionally encrypted for secrets.
reshifter - https://github.com/mhausenblas/reshifter - (last commit dec 2018)


## Architecture

Velero uses Azure Blob Storage for config backup (etcd) and volume snapshots of Azure managed disks to back up persistent storage.

## Client installation

    wget https://github.com/heptio/velero/releases/download/v1.0.0/velero-v1.0.0-linux-amd64.tar.gz
    tar zxvf velero-v1.0.0-linux-amd64.tar.gz
    sudo mv velero-v1.0.0-linux-amd64/velero /usr/bin/

## Storage setup

    az account set --subscription "Omnia Radix Development"

    # Create a Resource Group that will contain the backups. This is to separate permissions since velero needs Contributor access to the whole resource group.
    AZURE_BACKUP_RESOURCE_GROUP=Velero_Backups
    az group create -n $AZURE_BACKUP_RESOURCE_GROUP --location NorthEurope

    # Create a new storage account ID (yes, the name is weird because of weird name constraints and requirements of global uniqueness)
    AZURE_STORAGE_ACCOUNT_ID="radixvelerobackupsdev"
    az storage account create --name $AZURE_STORAGE_ACCOUNT_ID --resource-group $AZURE_BACKUP_RESOURCE_GROUP --sku Standard_GRS --encryption-services blob --https-only true --kind BlobStorage --access-tier Hot

    BLOB_CONTAINER=velero
    az storage container create -n $BLOB_CONTAINER --public-access off --account-name $AZURE_STORAGE_ACCOUNT_ID

    # Get subscription ID
    AZURE_SUBSCRIPTION_ID=`az account list --query '[?isDefault].id' -o tsv`
    AZURE_TENANT_ID=`az account list --query '[?isDefault].tenantId' -o tsv`

    # Create a new service principal. Optionally specify a password with `--password xxx`
    # az ad sp create-for-rbac --name "http://velero" --role "Contributor"

    RG_PATH=`az group show --name ${AZURE_BACKUP_RESOURCE_GROUP} | jq -r ".id"`

    # Get service principal password and client ID
    AZURE_CLIENT_SECRET=`az ad sp create-for-rbac --name "velero" --scope="${RG_PATH}" --role "Contributor" --query 'password' -o tsv`
    AZURE_CLIENT_ID=`az ad sp list --display-name "velero" --query '[0].appId' -o tsv`

    # Put credentials into file

    cat << EOF  > ./velero-credentials
    AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
    AZURE_TENANT_ID=${AZURE_TENANT_ID}
    AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
    AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
    EOF

    # Upload credentials to KeyVault
    az keyvault secret set \
        --vault-name radix-vault-dev \
        --name velero-credentials \
        --file velero-credentials

## Cluster installation

    # Download credentials file
    az keyvault secret download \
        --vault-name radix-vault-dev \
        --name velero-credentials \
        --file velero-credentials

    # Copy from above
    BLOB_CONTAINER=velero
    AZURE_BACKUP_RESOURCE_GROUP=Velero_Backups
    AZURE_STORAGE_ACCOUNT_ID=radixvelerobackupsdev


    # Add cluster specific MC group to credentials file
    CLUSTERNAME=stian-dr-g
    AZURE_RESOURCE_GROUP=MC_clusters_${CLUSTERNAME}_northeurope

    echo "AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP}" >> velero-credentials

    # Install velero
    velero install --provider azure --prefix $CLUSTERNAME --bucket $BLOB_CONTAINER --secret-file ./velero-credentials --backup-location-config resourceGroup=$AZURE_BACKUP_RESOURCE_GROUP,storageAccount=$AZURE_STORAGE_ACCOUNT_ID --snapshot-location-config apiTimeout=300s --wait

## Cluster removal (partial)

If for some reason you need to re-install Velero you need to do some manual cleanup first. If you update credentials and other information `velero install` will NOT update the corresponding secrets and backup locations in the cluster as you might expect.

    kubectl delete ns velero

    or

    kubectl delete secret -n velero cloud-credentials
    kubectl delete deployment -n velero velero
    kubectl delete BackupStorageLocation -n velero default
    kubectl delete volumesnapshotlocations -n velero default

## Operation

Gotcha: After running velero in `--restore-only` mode it's easy to forget to revert to "read/write" mode. You will still be able to create new backup jobs but they will be queued in pending until you remove `--restore-only` with no warnings or notifications that the jobs are only queued and might never start.

To find out if velero is in 
    
    --restore-only mode:
    kubectl get deploy/velero -n velero -o=jsonpath='{.spec.template.spec.containers[0].args}'

Set read/write mode:

    kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server"]}]}}}}'

Set restore-only mode:

    kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server", "--restore-only"]}]}}}}'

(Yes, this is the official way of changing between read only and read write according to Velero Slack)

This behaviour will change in version 1.1 when read/read-write will apply to the storage location rather than the server itself: https://github.com/heptio/velero/pull/1517

PS: If a restore has warnings (shown in `velero restore get`) they will not show up in the logs. You need to `velero restore describe backupname-1234` to view warnings (and probably errors).

### Ordering

In https://github.com/heptio/velero/issues/424 CRDs was added as a prioritized resource to be restored first. However, there is a time lag before the CRDs are "installed" in the cluster and if adding a CR before that will fail. There is a separate (open) issue here (https://github.com/heptio/velero/issues/964) about how to wait for CRDs to be ready before restoring CRs. Unfortunately the issue has been inactive for 8 months.

A work around to this might be to run two individual backups. One with ONLY CRDs and one excluding CRDs. Will investigate.

First backup: Resources in kube-system namespace AND global resources:

    velero backup create backup-system1 --exclude-namespaces velero --include-namespaces kube-system --include-cluster-resources=true --wait

    velero backup create backup-data1 --exclude-namespaces velero,kube-system --include-cluster-resources=false --wait

This does come with the possibility of inconsistencies if significant changes are done to global resources (CRDs) or kube-system in the time between the two backups, but the probability is very low.


### Scheduled backups

    velero schedule create full-daily --schedule="0 1 * * *" --selector 'backup notin (ignore)'

Default TTL for scheduled backups is 30 days but can be overwritten with --ttl 60d for example.

### On demand backups

    kubectl label secret -n velero cloud-credentials backup=ignore

    velero backup create backupname2 --selector 'backup notin (ignore)'

    kubectl logs -f -n velero deploy/velero

### Restore

#### Restore on to a blank cluster (disaster recovery)

    velero backup get

First set --restore-only on the new/target cluster, that way velero will not overwrite backups on the source storage before restore.

    kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server", "--restore-only"]}]}}}}'

Then add the source bucket (prefix) as a new BackupStorageLocation:

    cat <<EOF | kubectl apply -n velero -f -
    apiVersion: velero.io/v1
    kind: BackupStorageLocation
    metadata:
        name: stian-dr-f
        labels:
            component: velero
    spec:
        provider: azure
        config:
            resourceGroup: Velero_Backups
            storageAccount: radixvelerobackupsdev
        objectStorage:
            bucket: velero
            prefix: stian-dr-f
    EOF

Restart velero by deleting the pod for it to pick up the new location

Then restore the system components and CRDs:

    velero restore create --from-backup system-hourly-20190628110044 --wait

And finally the actual component objects:

    velero restore create --from-backup data-hourly-20190628110044 --wait

Delete the source backup location after restoring before enabling read/write mode again:

    kubectl delete BackupStorageLocation sourcebucket -n velero
    kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server"]}]}}}}'

PS: In an upcomming release of velero it will be possible to set read/write on a per location basis rather than per server.

##### Post-restore actions

Prometheus will not start since it's PersistentVolume is gone. Fix by deleting the StatefulSet and let prometheus-operator re-create it from scratch.

    kubectl delete pvc prometheus-prometheus-operator-prometheus-db-prometheus-prometheus-operator-prometheus-0
    kubectl delete statefulset prometheus-prometheus-operator-prometheus

PS: On one restore the prometheus object was not actually restored. Had to restore `data-hourly` again for it to appear.

If the cluster you have restored from is still active we might get a trashing/update loop between the old and new external-dns instances. This again might cause us to be rate-limited (max 500 updates in 5 minutes) by Azure in addition to constantly flipping DNS records.

Scale the external-dns instance that is no longer needed with:

    kubectl patch deployment external-dns --patch '{"spec": {"replicas": 0}}'

The NetworkPolicies added by the operator to all user environments (that allows the ingress-controller and Prometheus to access user components) uses a label on the default namespace in the rules. Velero does not change/update/merge between new and existing objects so that label will not be added to the default namespace and hence block the ingress from forwarding traffic to user components. We fix it by adding the label:

    kubectl label namespace default purpose=radix-base-ns

#### Restore on to a cluster with latest base components and Radix apps (migration)

# Big oops: `install_base_components.sh` cannot run on a new cluster
Due to the script relying on the cluster name being the cluster name. Which after a restore it's not actually any more.

## Metrics

Velero introduced metrics in https://github.com/heptio/velero/issues/84 , however it uses the not-recommended annotation way of exposing itself. The preferred way is using ServiceMonitors but https://github.com/coreos/kube-prometheus/pull/16 contains the code snippet to add the necessary config to make it work using the prometheus-operator helm chart.

Prometheus advices against using annotations because if limited flexibility in https://github.com/coreos/prometheus-operator/issues/1547 and https://github.com/prometheus/prometheus/pull/4131 and several other issues.

It does however work for simple use cases so I consider it best to enable support for annotations than adding custom service and servicemonitors to velero.

Adding support for prometheus scrape annotations in https://github.com/equinor/radix-platform/pull/161

Available metrics:

    # HELP velero_backup_attempt_total Total number of attempted backups
    # TYPE velero_backup_attempt_total counter
    velero_backup_attempt_total{schedule=""} 0
    # HELP velero_backup_deletion_attempt_total Total number of attempted backup deletions
    # TYPE velero_backup_deletion_attempt_total counter
    velero_backup_deletion_attempt_total{schedule=""} 0
    # HELP velero_backup_deletion_failure_total Total number of failed backup deletions
    # TYPE velero_backup_deletion_failure_total counter
    velero_backup_deletion_failure_total{schedule=""} 0
    # HELP velero_backup_deletion_success_total Total number of successful backup deletions
    # TYPE velero_backup_deletion_success_total counter
    velero_backup_deletion_success_total{schedule=""} 0
    # HELP velero_backup_failure_total Total number of failed backups
    # TYPE velero_backup_failure_total counter
    velero_backup_failure_total{schedule=""} 0
    # HELP velero_backup_partial_failure_total Total number of partially failed backups
    # TYPE velero_backup_partial_failure_total counter
    velero_backup_partial_failure_total{schedule=""} 0
    # HELP velero_backup_success_total Total number of successful backups
    # TYPE velero_backup_success_total counter
    velero_backup_success_total{schedule=""} 0
    # HELP velero_backup_total Current number of existent backups
    # TYPE velero_backup_total gauge
    velero_backup_total 0
    # HELP velero_restore_attempt_total Total number of attempted restores
    # TYPE velero_restore_attempt_total counter
    velero_restore_attempt_total{schedule=""} 1
    # HELP velero_restore_failed_total Total number of failed restores
    # TYPE velero_restore_failed_total counter
    velero_restore_failed_total{schedule=""} 0
    # HELP velero_restore_partial_failure_total Total number of partially failed restores
    # TYPE velero_restore_partial_failure_total counter
    velero_restore_partial_failure_total{schedule=""} 1
    # HELP velero_restore_success_total Total number of successful restores
    # TYPE velero_restore_success_total counter
    velero_restore_success_total{schedule=""} 0
    # HELP velero_restore_total Current number of existent restores
    # TYPE velero_restore_total gauge
    velero_restore_total 2
    # HELP velero_restore_validation_failed_total Total number of failed restores failing validations
    # TYPE velero_restore_validation_failed_total counter
    velero_restore_validation_failed_total{schedule=""} 0
    # HELP velero_volume_snapshot_attempt_total Total number of attempted volume snapshots
    # TYPE velero_volume_snapshot_attempt_total counter
    velero_volume_snapshot_attempt_total{schedule=""} 0
    # HELP velero_volume_snapshot_failure_total Total number of failed volume snapshots
    # TYPE velero_volume_snapshot_failure_total counter
    velero_volume_snapshot_failure_total{schedule=""} 0
    # HELP velero_volume_snapshot_success_total Total number of successful volume snapshots
    # TYPE velero_volume_snapshot_success_total counter
    velero_volume_snapshot_success_total{schedule=""} 0


## Other

We cannot add labels to all namespaces: https://github.com/kubernetes/kubernetes/issues/52326

Notes: Documentation is a bit sparse. Backed up files should be viewable manually by downloading from the remote storage. Mentions of possible problems when restoring service objects due to LoadBalancer IP assignments and integrations with cloud providers.

Moving customer secrets out of Kubernetes objects will greatly improve security overall as well as simplify backups. (Or maybe not, what if we back up the KeyVault credentials? Chicken-and-egg problem).

We should probably talk to users how they view the tradeoff of downtime requiring manual intervention after disaster recovery and maybe migration to avoid storing their credentials, or having their credentials persisted outside clusters in case of emergencies.


Out-of-cluster secrets:
sops - only CLI to encrypt yaml/json
kubesec - does not support Azure (inspired by sops)
https://github.com/Azure/kubernetes-keyvault-flexvol - does not provide stuff as env vars, only mount files. Will also be a hassle to integrate since it requires lots of pod values to be specified as well as a secret with credentials.
https://github.com/futuresimple/helm-secrets - wraps sops. encrypts secret portions of values.yaml files. Uses PGP.
https://github.com/StackExchange/blackbox - general git file encryption


# Protips

When working with velero logs, looking for errors and warnings is difficult. Filter out all `info` messages:

    velero restore logs backup-system2-20190620182150|grep -v "level=info"