# Velero

Official docs, https://heptio.github.io/velero/v0.11.0/

## Purpose

- _Disaster Recovery_  
  Sudden loss of cluster, all config and persisted data.  
  The goal is to restore Radix platform itself as well as running applications with minimal downtime and user intervention.  

- _Planned migration_  
  Need to move configuration and persistent data from one healthy cluster to another with minimal downtime. We want to use Planned migration to also reduce configuration drift.  

- _Possible other use-cases_  
  Clone a cluster and do a test-upgrade on the shadow cluster.  
  Snapshot before in-place upgrade. Provides a possible way of roll-back in case of problems after upgrade.

## Constraints/limitations

- _No support for cross-cloud DR_  
  that would involve transporting backups to a different cloud vendor causing all kinds of new challenges  

- _No backup of persistant storage_

## Architecture

_Infrastructure_  
- _Azure resource group_  
 to limit acccess to backups and because Velero has to have Contributor access to the rg  

- _Azure Blob Storage_  
  for storing backup of configs (etcd)  

- _Azure storage account and service principal_  
 for automation purposes

Velero
- Configuration is handled by Velero k8s CRDs
- Radix installation and configuration manifests are stored in config repo (flux)


## Installation

### Step 1: Install client

```sh
wget https://github.com/heptio/velero/releases/download/v1.0.0/velero-v1.0.0-linux-amd64.tar.gz
tar zxvf velero-v1.0.0-linux-amd64.tar.gz
sudo mv velero-v1.0.0-linux-amd64/velero /usr/bin/
``` 

### Step 2: Install infrastructure per environment

Dev/Prod.

Handled by scripts [bootstrap.sh](./bootstrap.sh)

### Step 3: Install in cluster

Managed by Flux, see [radix-flux](https://github.com/equinor/radix-flux) repo.  

1. Install velero flux prerequisites in the target cluster by executing the `install_base_components.sh` script  
    This will create the namespace `velero`, secret and configmap later used by flux
2. Sync flux in target cluster (wait for timer or use fluxctl)  
    The velero flux manifest will now use the prerequisite secret and configmap to install the velero helm chart

## Removal

### Remove from cluster

Removing Velero from a cluster is a three-step operation:

```sh
# Deleting the namespace will also delete the flux helmRelease, which again trigger a helm delete --purge
kubectl delete namespace/velero
# Clean up that which is unfortunately not removed by helm delete
kubectl delete clusterrolebinding/velero
kubectl delete crds --selector=app.kubernetes.io/name=velero
```

### Remove infrastructure from an environment

Dev/Prod.

Handled by script [teardown.sh](./teardown.sh)

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






