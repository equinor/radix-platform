# Restore

Backups are stored in azure blob containers.  
First find the name of the backup you want to restore by either inspecting the storage account in azure (see names in `velero.env`) or use the velero client, and then run the restore apps script.

1. Find the backup  
   ```sh
   velero backup get
   ```
1. Run restore script     
   ```sh
   # See header of script for details on usage
   RADIX_ENVIRONMENT=dev SOURCE_CLUSTER=weekly-25 BACKUP_NAME=all-hourly-20190703064411 ./restore_apps.sh
   ```

## Troubleshooting

### Warnings

If a restore has warnings (shown in `velero restore get`) they will not show up in the logs.  
You need to `velero restore describe backupname-1234` to view warnings (and probably errors).