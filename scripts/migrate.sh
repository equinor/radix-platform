#!/bin/bash

# USAGE
#
# Example: Restore into same cluster from where the backup was done
# SUBSCRIPTION_ENVIRONMENT=prod SOURCE_CLUSTER=prod-1 DEST_CLUSTER=prod-2 CLUSTER_TYPE=production ./migrate.sh
# SUBSCRIPTION_ENVIRONMENT=dev SOURCE_CLUSTER=playground-4 DEST_CLUSTER=playground-5 CLUSTER_TYPE=playground ./migrate.sh
# SUBSCRIPTION_ENVIRONMENT=dev SOURCE_CLUSTER=weekly-33 DEST_CLUSTER=weekly-34 ./migrate.sh

# INPUTS:
#
#   SUBSCRIPTION_ENVIRONMENT    (Mandatory. Example: prod|dev)
#   SOURCE_CLUSTER              (Mandatory. Example: prod1)
#   DEST_CLUSTER                (Mandatory. Example: prod2)
#   CLUSTER_TYPE                (Optional. Defaulted if omitted. ex: "production", "playground", "development")
#   SILENT_MODE                 (Optional. Defaulted if omitted. ex: false,true. Will skip any user input, so that script can run to the end with no interaction)

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nError: Azure-CLI not found in PATH. Exiting...";  exit 1; }
hash kubectl 2> /dev/null  || { echo -e "\nError: kubectl not found in PATH. Exiting...";  exit 1; }
hash envsubst 2> /dev/null  || { echo -e "\nError: envsubst not found in PATH. Exiting...";  exit 1; }
printf "Done."
echo ""


#######################################################################################
### Resolve dependencies on other scripts
###

WORKDIR_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CREATE_CLUSTER_PATH="$WORKDIR_PATH/aks/bootstrap.sh"
if ! [[ -x "$CREATE_CLUSTER_PATH" ]]; then
   # Print to stderror
   echo "The bootstrap script is not found or it is not executable in path $CREATE_CLUSTER_PATH" >&2 
fi

INSTALL_BASECOMPONENTS_PATH="$WORKDIR_PATH/install_base_components.sh"
if ! [[ -x "$INSTALL_BASECOMPONENTS_PATH" ]]; then
   # Print to stderror
   echo "The install base components script is not found or it is not executable in path $INSTALL_BASECOMPONENTS_PATH" >&2 
fi

RESTORE_APPS_PATH="$WORKDIR_PATH/velero/restore/restore_apps.sh"
if ! [[ -x "$RESTORE_APPS_PATH" ]]; then
   # Print to stderror
   echo "The restore apps script is not found or it is not executable in path $RESTORE_APPS_PATH" >&2 
fi

CREATE_ALIAS_PATH="$WORKDIR_PATH/create_alias.sh"
if ! [[ -x "$CREATE_ALIAS_PATH" ]]; then
   # Print to stderror
   echo "The create alias script is not found or it is not executable in path $CREATE_ALIAS_PATH" >&2 
fi

#######################################################################################
### Validate mandatory input
###

if [[ -z "$SUBSCRIPTION_ENVIRONMENT" ]]; then
    echo "Please provide SUBSCRIPTION_ENVIRONMENT. Value must be one of: \"prod\", \"dev\"."
    exit 1
fi

if [[ -z "$SOURCE_CLUSTER" ]]; then
    echo "Please provide SOURCE_CLUSTER."
    exit 1
fi

if [[ -z "$DEST_CLUSTER" ]]; then
    echo "Please provide DEST_CLUSTER."
    exit 1
fi

if [[ -z "$RESOURCE_GROUP" ]]; then
    RESOURCE_GROUP="clusters"
fi

if [[ -z "$CLUSTER_TYPE" ]]; then
    CLUSTER_TYPE="development"
fi

if [[ -z "$SILENT_MODE" ]]; then
    SILENT_MODE=false
fi

BACKUP_NAME="migration-$(date '+%Y%m%d%H%M%S')"

# Print inputs
echo -e ""
echo -e "Start restore using the following settings:"
echo -e "SUBSCRIPTION_ENVIRONMENT   : $SUBSCRIPTION_ENVIRONMENT"
echo -e "RESOURCE_GROUP             : $RESOURCE_GROUP"
echo -e "SOURCE_CLUSTER             : $SOURCE_CLUSTER"
echo -e "DEST_CLUSTER               : $DEST_CLUSTER"
echo -e "CLUSTER_TYPE               : $CLUSTER_TYPE"
echo -e "BACKUP_NAME                : $BACKUP_NAME"
echo -e "SILENT_MODE                : $SILENT_MODE"
echo -e ""

# Check for Azure login
echo "Checking Azure account information"

AZ_ACCOUNT="$(az account list | jq '.[] | select(.isDefault == true)')"
echo -n "You are logged in to subscription "
echo -n $AZ_ACCOUNT | jq '.id'
echo -n "Which is named " 
echo -n $AZ_ACCOUNT | jq '.name'
echo -n "As user " 
echo -n $AZ_ACCOUNT | jq '.user.name'
echo ""

if [[ $SILENT_MODE != true ]]; then
    read -p "Is this correct? (Y/n) " correct_az_login
    if [[ $correct_az_login =~ (N|n) ]]; then
    echo "Please use 'az login' command to login to the correct account. Quitting."
    exit 1
    fi
fi

#######################################################################################
### Connect kubectl
###

# Exit if source cluster does not exist
echo ""
echo "Verifying source cluster existence..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$RESOURCE_GROUP"  --name "$SOURCE_CLUSTER" 2>&1)"" == *"ERROR"* ]]; then    
    # Send message to stderr
    echo -e "Error: Source cluster \"$SOURCE_CLUSTER\" not found." >&2
    exit 0        
fi

# Give option to create dest cluster if it does not exist
echo ""
echo "Verifying destination cluster existence..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$RESOURCE_GROUP"  --name "$DEST_CLUSTER" 2>&1)"" == *"ERROR"* ]]; then    
    if [[ $SILENT_MODE != true ]]; then
        read -p "Destination cluster does not exists. Create cluster? (Y/n) " create_dest_cluster
        if [[ $create_dest_cluster =~ (N|n) ]]; then
            echo "Aborting..."
            exit 1
        fi
    fi

    # Copy spec of source cluster
    # NOTE: The normal spec of a cluster is determined by the (dev.env|prod.env in the AKS folder)
    NUM_NODES_IN_SOURCE_CLUSTER="$(kubectl get nodes --no-headers | wc -l | tr -d '[:space:]')"

    echo ""
    echo "Creating destination cluster..."   
    (AZ_INFRASTRUCTURE_ENVIRONMENT="$SUBSCRIPTION_ENVIRONMENT" CLUSTER_NAME="$DEST_CLUSTER" NODE_COUNT="$NUM_NODES_IN_SOURCE_CLUSTER" SILENT_MODE="$SILENT_MODE" source "$CREATE_CLUSTER_PATH")
    wait # wait for subshell to finish
    printf "Done creating cluster."

    echo ""
    echo "Installing base components..." 
    (SUBSCRIPTION_ENVIRONMENT="$SUBSCRIPTION_ENVIRONMENT" CLUSTER_NAME="$DEST_CLUSTER" CLUSTER_TYPE="$CLUSTER_TYPE" SILENT_MODE="$SILENT_MODE" source "$INSTALL_BASECOMPONENTS_PATH")
    wait # wait for subshell to finish
    printf "Done installing base components."

fi

# Connect kubectl so we have the correct context
echo ""
printf "Point to destination cluster... "
az aks get-credentials --overwrite-existing --admin --resource-group "$RESOURCE_GROUP"  --name "$DEST_CLUSTER"

# Wait for operator to be deployed from flux
echo ""
echo "Waiting for radix-operator to be deployed by flux-operator so that it can handle migrated apps"
echo "If this lasts forever are you migrating to a cluster without base components installed?"
while [[ "$(kubectl get deploy radix-operator 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done

echo ""
printf "Point to source cluster... "
az aks get-credentials --resource-group "$RESOURCE_GROUP"  --name "$SOURCE_CLUSTER" \
    --overwrite-existing \
    --admin \
    2>&1 >/dev/null
printf "Done.\n"

echo ""
printf "Making backup of source cluster... "

cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  labels:
    velero.io/storage-location: default
  name: $BACKUP_NAME
  namespace: velero
spec:
  excludedNamespaces:
  - velero
  - kube-system
  excludedResources:
  - pv
  - pvc
  hooks:
    resources: null
  includeClusterResources: true
  includedNamespaces:
  - '*'
  includedResources:
  - '*'
  labelSelector:
    matchExpressions:
    - key: release
      operator: NotIn
      values:
      - prometheus-operator
  storageLocation: default
  ttl: 168h0m0s
  volumeSnapshotLocations:
  - default
EOF

echo ""
printf "Restore into destination cluster... "
(SUBSCRIPTION_ENVIRONMENT="$SUBSCRIPTION_ENVIRONMENT" SOURCE_CLUSTER="$SOURCE_CLUSTER" DEST_CLUSTER="$DEST_CLUSTER" BACKUP_NAME="$BACKUP_NAME" SILENT_MODE="$SILENT_MODE" source "$RESTORE_APPS_PATH")
wait # wait for subshell to finish
printf "Done restoring into cluster."


echo ""
printf "Point to source cluster... "
az aks get-credentials --resource-group "$RESOURCE_GROUP"  --name "$SOURCE_CLUSTER" \
    --overwrite-existing \
    --admin \
    2>&1 >/dev/null
printf "Done.\n"

echo ""
printf "Delete custom ingresses... "
while read -r line; do
    if [[ "$line" ]]; then
        helm delete ${line} --purge
    fi
done <<< "$(helm list --short | grep radix-ingress)"

echo ""
printf "Point to destination cluster... "
az aks get-credentials --overwrite-existing --admin --resource-group "$RESOURCE_GROUP"  --name "$DEST_CLUSTER"

echo ""
printf "Create aliases in destination cluster... "
(SUBSCRIPTION_ENVIRONMENT="$SUBSCRIPTION_ENVIRONMENT" CLUSTER_NAME="$DEST_CLUSTER" CLUSTER_TYPE="$CLUSTER_TYPE" BACKUP_NAME="$BACKUP_NAME" SILENT_MODE="$SILENT_MODE" source "$CREATE_ALIAS_PATH")
wait # wait for subshell to finish
printf "Done creating aliases."

echo ""
echo "###########################################################"
echo ""
echo "NOTE: You need to manually activate the cluster"
echo ""
echo "You do this in the https://github.com/equinor/radix-flux repo"
echo ""
echo "###########################################################"