#!/bin/bash

# PURPOSE
# Reset the destination cluster found in kubectl current context for anything the restore_apps.sh script produced.
#
# USAGE
# ./reset_restore_apps.sh

DESTINATION_CLUSTER="$(kubectl config current-context)"

echo ""
echo "WARNING!"
echo "This script is a tool for testing restore operations in a development cluster."
echo "The intention is to reset the destination cluster for anything the restore_apps.sh script produced."
echo "You cannot undo the actions performed by this script."
echo ""
echo "Current cluster is: $DESTINATION_CLUSTER"
echo ""

read -p "Are you sure you want to continue? (Y/n) " really_sure
if [[ $really_sure =~ (N|n) ]]; then
  echo "Chicken!"
  exit 1
fi

echo ""
echo "Removing all rr..."
kubectl delete rr --all
# wait until all radix app namespaces are gone

echo ""
echo "Waiting for all radix app namespaces to be deleted..."
while [[ "$(kubectl get ns --selector='radixApp' --output=name)" != "" ]]; do   
   printf "."
   sleep 2s
done
echo "Done."

echo ""
echo "Removing all restore sets..."
kubectl delete restore --all -n velero

echo ""
echo "Configure velero back to normal operation in destination..."

# Set velero in destination to read destination backup location
PATCH_JSON="$(cat << END
{
   "spec": {
      "objectStorage": {
         "bucket": "$DESTINATION_CLUSTER"
      }
   }
}
END
)"
kubectl patch BackupStorageLocation default -n velero --type merge --patch "$(echo $PATCH_JSON)"
# Set velero in read/write mode
kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server"]}]}}}}'

echo ""
echo "All done & gone!"