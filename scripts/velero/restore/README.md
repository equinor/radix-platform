# Restore

Handled by script and the use of restore manifests to define what and how we want to restore.  
See header of [./restore_apps.sh](./restore_apps.sh) for details on usage.


## Troubleshooting

### Warnings

If a restore has warnings (shown in `velero restore get`) they will not show up in the logs.  
You need to `velero restore describe backupname-1234` to view warnings (and probably errors).