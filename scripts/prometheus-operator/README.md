# Prometheus Operator

## Prometheus database backup and restore

`prometheus-db-backup.sh` stores a Prometheus TSDB snapshot in Azure Blob
Storage. `prometheus-db-restore.sh` restores a selected snapshot later into a
new or replacement cluster. Each script uses a temporary Azure managed disk
only while transferring the archive.

Create a backup:

```sh
RADIX_ZONE=dev CLUSTER=weekly-33 ./prometheus-db-backup.sh
```

Restore a named backup:

```sh
RADIX_ZONE=dev BACKUP_CLUSTER=weekly-33 CLUSTER=weekly-34 \
BACKUP_NAME=prometheus-backup-20260820143000 ./prometheus-db-restore.sh
```

The cluster must already have `kube-prometheus-stack` installed and
the Prometheus data PVC name expected by
`prometheus-restore-job.yaml`.

### Prometheus Migration

This describes the previous single-run backup and restore flow. It remains as a
reference for the temporary-disk staging mechanism, but is no longer performed
by `prometheus-db-backup.sh`.

#### Prometheus Backup Flow

```mermaid
flowchart TD
    start([Start]) --> validate[Validate tools, inputs,<br/>Azure session, and access]
    validate --> ready{Source Prometheus ready<br/>and disk usage <= 50%?}
    ready -- No --> stop([Stop])
    ready -- Yes --> disk[Create temporary<br/>managed disk]
    disk --> mount[Create source PV/PVC<br/>and mount /backup]
    mount --> snapshot[Create Prometheus TSDB snapshot]
    snapshot --> hook[Velero pre-hook archives<br/>/prometheus/snapshots]
    hook --> backup[Start Velero backup]
    backup --> wait[Wait until backup is Completed]
    wait --> cleanup[Restore source settings<br/>and remove source resources]
    cleanup --> handoff[(Retained temporary disk<br/>contains prometheusbackup.tar)]
```

#### Prometheus Restore Flow

```mermaid
flowchart TD
    handoff[(Temporary disk<br/>contains prometheusbackup.tar)] --> setup[Apply PV/PVC in destination]
    setup --> pause[Pause Flux and scale<br/>Prometheus to zero]
    pause --> restore[Restore job extracts archive into<br/>the Prometheus data PVC]
    restore --> cleanup[Delete restore Job, PVC, PV,<br/>and temporary disk]
    cleanup --> complete([Scale Prometheus up<br/>and complete])
```

The archive is created by the pre-hook after the Prometheus snapshot job has
completed. The destination restore job reads the archive from the same Azure
disk and extracts it into the destination Prometheus data PVC. The final PVC
and PV deletion removes the retained temporary disk through the PV reclaim
policy.

### Durable backup and delayed restore

To migrate at a later time, split the current script into a backup script and
a restore script. Store the archive in the cluster's existing Velero container,
under `backups/prometheus/`. The zone's Velero storage account is available to
scripts as `velero_sa` through `environment_json` and is named
`radixvelero{environment}`.

For example, a backup from `weekly-33` in the development environment is
stored at:

```text
radixvelerodev / weekly-33 / backups / prometheus / prometheus-backup-20260820143000.tar
```

The layout of the `weekly-33` container is then:

```text
backups/                Velero-managed backup data
    prometheus/           Prometheus TSDB archives managed by these scripts
        prometheus-backup-<timestamp>.tar
        prometheus-backup-<timestamp>.manifest.json
restores/               Velero-managed restore data
```

```mermaid
flowchart TD
    subgraph backup[1. prometheus-db-backup.sh]
        preflight[Validate inputs, Azure access,<br/>PIM role, and cluster]
        staging[Create temporary Azure disk,<br/>PV, and PVC]
        prepare[Pause Flux and patch Prometheus:<br/>Admin API, /backup, backup sidecar]
        snapshot[Create TSDB snapshot]
        archive[Velero pre-hook in backup sidecar:<br/>archive /prometheus/snapshots]
        copy[AzCopy Job uploads prometheusbackup.tar<br/>with workload identity]
        checksum[Calculate SHA-256 and write manifest]
        upload[Upload archive and manifest to Blob Storage]
        cleanup[Restore Prometheus CR and Flux;<br/>wait for /backup to detach]
        delete[Delete temporary job, PVC, PV, and disk]
        preflight --> staging --> prepare --> snapshot --> archive --> copy --> checksum --> upload --> cleanup --> delete
    end

    subgraph storage[Azure Blob Storage]
        blob[(radixvelero env<br/>current cluster container<br/>backups/prometheus/prometheus-backup-timestamp.tar<br/>backups/prometheus/prometheus-backup-timestamp.manifest.json)]
    end

    subgraph restore[2. prometheus-db-restore.sh]
        select[Select backup ID and cluster]
        verify[Download manifest and verify checksum]
        stagingRestore[Create temporary disk, PV, and PVC]
        download[Copy archive to temporary PVC]
        stop[Pause Flux and scale Prometheus to zero]
        extract[Restore job extracts archive into Prometheus data PVC]
        restoreCleanup[Restore original replica count and Flux;<br/>delete temporary job, PVC, PV, and disk]
        select --> verify --> stagingRestore --> download --> stop --> extract --> restoreCleanup
    end

    upload --> blob
    blob --> verify

    cleanup --> released{Backup volume released?}
    released -- Yes --> delete
    released -- No --> preserve[Preserve PV and disk for recovery]
```

Both scripts use strict error handling and cleanup traps. On a failed backup,
the source Prometheus configuration and Flux release are restored before the
staging storage is removed. If the source Pod does not release the temporary
`/backup` volume, the script preserves the PV and disk instead of forcing a
detach that could leave a stale CSI attachment.

The scripts should use an immutable backup ID, for example
`prometheus-backup-YYYYMMDDHHMMSS`, as the Blob filename prefix. The restore
script must require that ID and cluster rather than selecting the newest backup
automatically.

#### Why Blob Storage

| Benefit | Temporary managed disk | Blob Storage |
| --- | --- | --- |
| Restore later | Deleted by the current migration flow | Retained until lifecycle policy removes it |
| Restore to a new cluster | Requires the source disk to remain available | Any authorized cluster can download the selected backup |
| Cost for inactive backups | Charges as provisioned disk capacity | Charges for stored bytes and selected access tier |
| Backup catalogue | No durable metadata | Cluster container, Blob prefix, and manifests identify each backup |
| Integrity verification | No persistent record | Store a SHA-256 checksum in the manifest |
| Retention | Manual disk management | Lifecycle policies can expire or tier old backups |

Use Azure AD data-plane authorization (`--auth-mode login` from the operator,
or a workload identity for uploader/downloader jobs) rather than storage account
keys. The existing Velero `BackupStorageLocation` already targets this storage
account and source-cluster container through the configured private network
path. The new uploader and downloader still need explicit Blob data-plane
authorization; a `BackupStorageLocation` does not itself grant another job
permission to upload or download blobs.

<!-- topk(5,radix_operator_request_sum) -->