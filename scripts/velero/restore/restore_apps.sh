#!/bin/bash

# PURPOSE
#
# Restore radix applications using a velero backup in any radix cluster.
# It will NOT restore PV or PVC.

# Regarding CR Restore manifests
# A restore operation can be defined as a velero custom resource of type "Restore".
# See example "restore_rr.yaml" for restoring radix registrations.
# These manifests are templated using shell variables.

# USAGE
#
# Example: Restore into same cluster from where the backup was done
# SUBSCRIPTION_ENVIRONMENT=dev SOURCE_CLUSTER=weekly-25 BACKUP_NAME=all-hourly-20190703064411 ./restore_apps.sh
#
# Example: Restore into different cluster from where the backup was done
# SUBSCRIPTION_ENVIRONMENT=dev SOURCE_CLUSTER=prod-1 DEST_CLUSTER=prod-2 BACKUP_NAME=all-hourly-20190703064411 ./restore_apps.sh
# SUBSCRIPTION_ENVIRONMENT=dev SOURCE_CLUSTER=iknu-velero-test-source DEST_CLUSTER=iknu-velero-test-dest BACKUP_NAME=radix-backup-all ./restore_apps.sh

# DEVELOPMENT
#
# To "reset" the destination cluster when testing this script then you can use the "reset_restore_apps.sh" script.

# KNOWN ISSUES
#
# >> Missing "envsubst" on mac
# Tool "envsubst" is available by default in linux, but not in macOs.
# For macOs it is included in the "gettext" package and is installed and linked using brew
# $brew install gettext
# $brew link --force gettext
#
# >> Restore resource X failed
# We need to restore radix resources in a specific order and give the radix-operator enough time to work with
# them before moving on to restoring the next resource.
# This time interval is as for now simply a sleep for a "I hope this is long enough" time.
# Often adjusting the time before the resource restore that failed will fix the problem.
# The "ultimate" solution is to have a proper check that the radix-operator has finished processing the
# previous resource before continuing on, but this is a TODO in both this script and radix-operator (future: CR status field).

# INPUTS:
#
#   SUBSCRIPTION_ENVIRONMENT    (Mandatory. Example: prod|dev)
#   SOURCE_CLUSTER              (Mandatory. Example: prod1)
#   BACKUP_NAME                 (Mandatory. Example: all-hourly-20190703064411)
#   DEST_CLUSTER                (Optional. Example: prod2)
#   RESOURCE_GROUP              (Optional. Example: "clusters")
#   USER_PROMPT                 (Optional. Defaulted if omitted. ex: false,true. Will skip any user input, so that script can run to the end with no interaction)


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

ADD_REPLY_URL_SCRIPT="$WORKDIR_PATH/../../add_reply_url_for_cluster.sh"
if ! [[ -x "$ADD_REPLY_URL_SCRIPT" ]]; then
   # Print to stderror
   echo "The replyUrl script is not found or it is not executable in path $ADD_REPLY_URL_SCRIPT" >&2 
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

if [[ -z "$BACKUP_NAME" ]]; then
    echo "Please provide BACKUP_NAME."
    exit 1
fi

if [[ -z "$DEST_CLUSTER" ]]; then
    DEST_CLUSTER="$SOURCE_CLUSTER"
fi

if [[ -z "$RESOURCE_GROUP" ]]; then
    RESOURCE_GROUP="clusters"
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Print inputs
echo -e ""
echo -e "Start restore using the following settings:"
echo -e "SUBSCRIPTION_ENVIRONMENT   : $SUBSCRIPTION_ENVIRONMENT"
echo -e "RESOURCE_GROUP             : $RESOURCE_GROUP"
echo -e "SOURCE_CLUSTER             : $SOURCE_CLUSTER"
echo -e "DEST_CLUSTER               : $DEST_CLUSTER"
echo -e "BACKUP_NAME                : $BACKUP_NAME"
echo -e "USER_PROMPT                : $USER_PROMPT"
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

if [[ $USER_PROMPT == true ]]; then
    read -p "Is this correct? (Y/n) " correct_az_login
    if [[ $correct_az_login =~ (N|n) ]]; then
    echo "Please use 'az login' command to login to the correct account. Quitting."
    exit 1
    fi
fi


#######################################################################################
### Support funcs
###

function please_wait() {
  # Loop for $1 iterations.
  # For every iteration, sleep 1s and print $2 delimiter.
  local iteration_end="${1:-5}"
  local delimiter_default="."
  local delimiter="${2:-$delimiter_default}"
  local iterator=0
  
  while [[ "$iterator" != "$iteration_end" ]]; do
    iterator="$((iterator+1))"
    printf "$delimiter"
    sleep 1s
  done
  echo "Done."
}


#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
echo ""
echo "Connecting kubectl to vendelo-destination..."
if [[ ""$(az aks get-credentials --overwrite-existing --admin --resource-group "$RESOURCE_GROUP"  --name "$DEST_CLUSTER" 2>&1)"" == *"ERROR"* ]]; then    
   # Send message to stderr
   echo -e "Error: Cluster \"$DEST_CLUSTER\" not found." >&2
   exit 0        
fi


#######################################################################################
### Configure velero for restore in destinaton
###

echo ""
echo "Configure velero for restore in destination cluster \"DEST_CLUSTER\"..."

# Set velero-destination to read-only
kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server", "--restore-only"]}]}}}}'
# Set velero in destination to read source backup location
PATCH_JSON="$(cat << END
{
   "spec": {
      "objectStorage": {
         "bucket": "$SOURCE_CLUSTER"
      }
   }
}
END
)"
kubectl patch BackupStorageLocation default -n velero --type merge --patch "$(echo $PATCH_JSON)"

echo ""
echo "Wait for backup \"$BACKUP_NAME\" to be available in destination cluster \"DEST_CLUSTER\" before we can restore..."
while [[ "$(velero backup describe $BACKUP_NAME 2>&1)" == *"error"* ]]; do
    printf "."
    sleep 2s
done
echo "Done."


#######################################################################################
### Restore data
###

echo ""
echo "Restore app registrations..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' < ${WORKDIR_PATH}/restore_rr.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

# TODO: How to determine when radix-operator is done?
echo ""
echo "Wait for registrations to be picked up by radix-operator..."
please_wait 10

echo ""
echo "Restore app config..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' < ${WORKDIR_PATH}/restore_ra.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

# TODO: How to determine when radix-operator is done?
echo ""
echo "Wait for app config to be picked up by radix-operator..."
please_wait 10

echo ""
echo "Restore deployments..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' < ${WORKDIR_PATH}/restore_rd.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

# TODO: How to determine when deployments are done?
echo "Wait for deployments to be picked up by radix-operator..."
please_wait 10

echo ""
echo "Restore jobs..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' < ${WORKDIR_PATH}/restore_rj.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

# TODO: How to determine when jobs are done?
echo "Wait for jobs to be picked up by radix-operator..."
please_wait 10

echo ""
echo "Restore app specific secrets..."
RESTORE_YAML="$(BACKUP_NAME="$BACKUP_NAME" envsubst '$BACKUP_NAME' < ${WORKDIR_PATH}/restore_secret.yaml)"
echo "$RESTORE_YAML" | kubectl apply -f -

# TODO: How to determine when secrets are done?
echo ""
echo "Wait for secrets to be picked up by radix-operator..."
please_wait 10


#######################################################################################
### Configure velero back to normal operation in destination
### 

echo ""
echo "Configure velero back to normal operation in destination..."

# Set velero in destination to read destination backup location
PATCH_JSON="$(cat << END
{
   "spec": {
      "objectStorage": {
         "bucket": "$DEST_CLUSTER"
      }
   }
}
END
)"
kubectl patch BackupStorageLocation default -n velero --type merge --patch "$(echo $PATCH_JSON)"
# Set velero in read/write mode
kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server"]}]}}}}'


#######################################################################################
### Update replyUrls for those radix apps that require AD authentication
### 

echo ""
echo "Updating replyUrls for those radix apps that require AD authentication"

echo ""
echo "Adding replyUrl for Grafana..."   
(AAD_APP_NAME="radix-cluster-aad-server-${SUBSCRIPTION_ENVIRONMENT}" K8S_NAMESPACE="default" K8S_INGRESS_NAME="grafana" REPLY_PATH="/login/generic_oauth" USER_PROMPT="$USER_PROMPT" source "$ADD_REPLY_URL_SCRIPT")
wait # wait for subshell to finish
printf "Done."

# Update replyUrl for web-console
echo ""
echo "Waiting for web-console ingress to be ready so we can add replyUrl to web console aad app..."
while [[ "$(kubectl get ing web -n radix-web-console-prod 2>&1)" == *"Error"* ]]; do
    printf "."
    sleep 5s
done
echo "Ingress is ready, adding replyUrl... "

echo ""
echo "Adding replyUrl for radix web-console..." 
# The web console has an aad app per cluster type. This script does not know about cluster type, so we will have to go with subscription environment.
if [[ "$SUBSCRIPTION_ENVIRONMENT" == "dev" ]]; then
    (AAD_APP_NAME="Omnia Radix Web Console - Development Clusters" K8S_NAMESPACE="radix-web-console-prod" K8S_INGRESS_NAME="web" REPLY_PATH="/auth-callback" USER_PROMPT="$USER_PROMPT" source "$ADD_REPLY_URL_SCRIPT")
    wait # wait for subshell to finish
    (AAD_APP_NAME="Omnia Radix Web Console - Playground Clusters" K8S_NAMESPACE="radix-web-console-prod" K8S_INGRESS_NAME="web" REPLY_PATH="/auth-callback" USER_PROMPT="$USER_PROMPT" source "$ADD_REPLY_URL_SCRIPT")
    wait # wait for subshell to finish
fi
if [[ "$SUBSCRIPTION_ENVIRONMENT" == "prod" ]]; then
    (AAD_APP_NAME="Omnia Radix Web Console - Production Clusters" K8S_NAMESPACE="radix-web-console-prod" K8S_INGRESS_NAME="web" REPLY_PATH="/auth-callback" USER_PROMPT="$USER_PROMPT" source "$ADD_REPLY_URL_SCRIPT")
    wait # wait for subshell to finish
fi
printf "Done."


#######################################################################################
### Done!
### 

echo ""
echo "All restore tasks are done!"

# Print restore status
echo "Run \"velero restore get\" to get latest status:"
velero restore get