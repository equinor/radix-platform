# Velero

Official docs, https://heptio.github.io/velero/v0.11.0/

## Purpose

* Disaster Recovery  
Sudden loss of cluster, all config and persisted data.  
The goal is to restore Radix platform itself as well as running applications with minimal downtime and user intervention.  

* Planned migration  
Need to move configuration and persistent data from one healthy cluster to another with minimal downtime. We want to use Planned migration to also reduce configuration drift.  

* Possible other use-cases  
Clone a cluster and do a test-upgrade on the shadow cluster.  
Snapshot before in-place upgrade. Provides a possible way of roll-back in case of problems after upgrade.

## Constraints/limitations

We do not support cross-cloud DR since that would involve transporting backups to a different cloud vendor causing all kinds of new challenges.

## Architecture

Velero uses Azure Blob Storage for config backup (etcd) and volume snapshots of Azure managed disks to back up persistent storage.  
Configuration is handled by Velero k8s CRDs or the Velero client tool.

## Installation

### Client

```sh
wget https://github.com/heptio/velero/releases/download/v1.0.0/velero-v1.0.0-linux-amd64.tar.gz
tar zxvf velero-v1.0.0-linux-amd64.tar.gz
sudo mv velero-v1.0.0-linux-amd64/velero /usr/bin/
``` 

### Infrastructure bootstrap and teardown

See scripts
- [bootstrap.sh](./bootstrap.sh)
- [teardown.sh](./teardown.sh)

### Cluster installation

Managed by Flux, see [radix-flux](https://github.com/equinor/radix-flux) repo.  

Removing Velero from a cluster is a three-step operation:

```sh
# First delete the flux helmRelease manifest for velero.
# This will trigger the flux-helm-operator to delete and purge the velero helm release.
kubectl delete helmRelease velero -n velero

# And then we need to remove all the things that are not cleaned up when deleting the helm release
kubectl delete namespace/velero clusterrolebinding/velero
kubectl delete crds --selector=app.kubernetes.io/name=velero
```

## Operation

### Restore

See script [./restore/restore_apps.sh](./restore/restore_apps.sh)

### General

Gotcha: After running velero in `--restore-only` mode it's easy to forget to revert to "read/write" mode. You will still be able to create new backup jobs but they will be queued in pending until you remove `--restore-only` with no warnings or notifications that the jobs are only queued and might never start.

#### Velero modes

*To find out which mode velero is in:*
```sh  
   kubectl get deploy/velero -n velero -o=jsonpath='{.spec.template.spec.containers[0].args}'
```

*Set read/write mode:*

```sh
    kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server"]}]}}}}'
```

*Set restore-only mode:*

```sh
    kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server", "--restore-only"]}]}}}}'
```

(Yes, this is the official way of changing between read only and read write according to Velero Slack)

This behaviour will change in version 1.1 when read/read-write will apply to the storage location rather than the server itself: https://github.com/heptio/velero/pull/1517

PS: If a restore has warnings (shown in `velero restore get`) they will not show up in the logs. You need to `velero restore describe backupname-1234` to view warnings (and probably errors).






