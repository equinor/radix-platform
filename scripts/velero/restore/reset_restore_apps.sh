#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Reset the destination cluster found in kubectl current context for anything the restore_apps.sh script produced.

#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../../radix-zone/radix_zone_dev.env CLUSTER_NAME="weekly-01" ./reset_restore_apps.sh

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
   echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
   exit 1
}

hash kubectl 2>/dev/null || {
   echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2
   exit 1
}
printf "All is good."
echo ""

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

if [[ -z "$CLUSTER_NAME" ]]; then
   echo "ERROR: Please provide CLUSTER_NAME" >&2
   exit 1
fi

# Source util scripts
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {
   # Send message to stderr
   echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
   exit 0
}
printf "...Done.\n"

#######################################################################################
### GO! GO! GO!
###

DESTINATION_CLUSTER="$(kubectl config current-context)"

echo ""
echo "WARNING!"
echo "This script is a tool for testing restore operations in a development cluster."
echo "The intention is to reset the destination cluster for anything the restore_apps.sh script produced."
echo "You cannot undo the actions performed by this script."
echo ""
echo "Current cluster is: $DESTINATION_CLUSTER"
echo ""

while true; do
   read -r -p "Are you sure you want to continue? (Y/n) " yn
   case $yn in
   [Yy]*) break ;;
   [Nn]*)
      echo ""
      echo "Chicken!"
      exit 0
      ;;
   *) echo "Please answer yes or no." ;;
   esac
done

echo ""
echo "Removing all rr..."
kubectl delete rr --all

# wait until all radix app namespaces are gone
echo ""
printf "Waiting for all radix app namespaces to be deleted..."
while [[ "$(kubectl get namespace --selector='radix-app' --output=name)" != "" ]]; do
   printf "."
   sleep 2
done
printf " Done.\n"

echo ""
echo "Removing all restore sets..."
kubectl delete restore --all --namespace velero

echo ""
echo "Configure velero back to normal operation in destination..."

# Set velero in destination to read destination backup location
PATCH_JSON="$(
   cat <<END
{
    "spec": {
      "accessMode":"ReadWrite",
       "objectStorage": {
            "bucket": "$SOURCE_CLUSTER"
       }
    }
 }
END
)"
# Set velero in read/write mode
kubectl patch BackupStorageLocation default --namespace velero --type merge --patch "$(echo $PATCH_JSON)"

echo ""
echo "All done & gone!"
