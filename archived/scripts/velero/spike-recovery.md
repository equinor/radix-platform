# Verification of Velero and backups

Part of [velero spike](./spike-result.md)

## Disaster recovery

Create a new cluster.
```sh
INFRASTRUCTURE_ENVIRONMENT=dev CLUSTER_NAME=stian-dr-d ./install_cluster.sh
```
Add an example application with a secret.

Works: www-radix-canary-dev.stian-dr-a.dev.radix.equinor.com

Add velero and set up scheduled backups. See that the monitoring works.

Delete the cluster with no teardown.

Create a new cluster excluding base components.

> Velero on the old cluster said status was Completed with no indications of error.
>
> Viewing on the new cluster: $ velero backup get NAME STATUS CREATED EXPIRES STORAGE > LOCATION SELECTOR backupname2 PartiallyFailed (3 errors)
>
> The logs are 2000+ lines but no obvious errors are popping out.

Restore backup using --restore mode to new cluster.

velero restore create --from-backup backupname2