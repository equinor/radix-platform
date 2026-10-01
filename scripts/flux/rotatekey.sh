#!/usr/bin/env bash

set -euo pipefail

#######################################################################################
# PURPOSE
#
#  1. Generate the flux ssh secret with the new key into the cluster
#  2. Update secret in keyvault
#  3. Update the flux ssh secret in the git repository.
#
# Normal usage
# RADIX_ZONE=dev CLUSTER_NAME="weekly-01" ./rotatekey.sh 
#######################################################################################

yel=$'\e[1;33m'
normal=$(tput sgr0 2>/dev/null || true)

# Required inputs

if [[ ${RADIX_ZONE:-} =~ ^(dev|playground|prod|c2|c3)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2|c3" >&2
    exit 1
fi

if [[ -z "${CLUSTER_NAME:-}" ]]; then
   echo "ERROR: Please provide CLUSTER_NAME" >&2
   exit 1
fi

#######################################################################################
### Check for prerequisites binaries
###

hash flux 2>/dev/null || {
    echo -e "\nERROR: flux not found in PATH. Exiting..." >&2
    exit 1
}

hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting... " >&2
    exit 1
}

hash yq 2>/dev/null || {
    echo -e "\nERROR: yq not found in PATH. Exiting..." >&2
    exit 1
}


REQ_FLUX_VERSION="2.9.3"
FLUX_VERSION=$(flux --version | awk '{print $3'})
if [[ "$FLUX_VERSION" != "${REQ_FLUX_VERSION}" ]]; then
    printf "${yel}Please update flux cli to ${REQ_FLUX_VERSION}. You got version $FLUX_VERSION${normal}\n"
    exit 1
fi
#######################################################################################
### Read Zone Config
###
RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source "${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh"

#######################################################################################
### Environment
###
printf "\n%s► Read YAML configfile $RADIX_ZONE"
RADIX_ZONE_ENV=$(config_path $RADIX_ZONE)
printf "\n%s► Read terraform variables and configuration"
RADIX_RESOURCE_JSON=$(environment_json $RADIX_ZONE)
RADIX_ZONE_YAML=$(cat <<EOF
$(<$RADIX_ZONE_ENV)
EOF
)
AZ_SUBSCRIPTION_ID=$(yq '.backend.subscription_id' <<< "$RADIX_ZONE_YAML")
AZ_RESOURCE_GROUP_CLUSTERS=$(jq -r .cluster_rg <<< "$RADIX_RESOURCE_JSON")
AZ_RESOURCE_KEYVAULT_CONFIG=$(jq -r .keyvault_config <<< "$RADIX_RESOURCE_JSON")
FLUX_PRIVATE_KEY_NAME="flux-github-deploy-key-private"

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"
echo ""

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" || {
   # Send message to stderr
   echo -e "ERROR: Cluster \"$CLUSTER_NAME\" not found." >&2
   exit 1
}
printf "...Done.\n"

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "   >  Rotate the flux key in a radix cluster:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e "   -  AZ_RESOURCE_GROUP_CLUSTERS       : $AZ_RESOURCE_GROUP_CLUSTERS"
echo -e "   -  Namespace secret                 : flux-system"
echo -e "   -  namespace                        : flux-system"
echo -e "   -  KEY Vault                        : $AZ_RESOURCE_KEYVAULT_CONFIG"
echo -e "   -  Secret                           : $FLUX_PRIVATE_KEY_NAME"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

USER_PROMPT=true

echo ""
if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -r -p "Is this correct? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            echo ""
            echo "Quitting."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
fi

FLUX_SECRET_BACKUP=$(mktemp)
if ! kubectl --context "$CLUSTER_NAME" -n flux-system get secret flux-system -o json |
    jq 'del(.metadata.creationTimestamp, .metadata.managedFields, .metadata.resourceVersion, .metadata.uid)' > "$FLUX_SECRET_BACKUP"; then
    echo "ERROR: Failed to back up the existing Flux secret." >&2
    rm -f "$FLUX_SECRET_BACKUP"
    exit 1
fi
FLUX_SECRET_REPLACED=false
cleanup() {
    exit_code=$?
    trap - EXIT

    rm -f "./${FLUX_PRIVATE_KEY_NAME}" "./${FLUX_PRIVATE_KEY_NAME}.pub"
    if [[ $exit_code -ne 0 && $FLUX_SECRET_REPLACED == true ]]; then
        echo "Restoring the previous Flux secret..." >&2
        kubectl --context "$CLUSTER_NAME" apply -f "$FLUX_SECRET_BACKUP" >/dev/null ||
            echo "ERROR: Failed to restore the previous Flux secret." >&2
    fi
    rm -f "$FLUX_SECRET_BACKUP"
    exit "$exit_code"
}
if [[ -e "./${FLUX_PRIVATE_KEY_NAME}" || -e "./${FLUX_PRIVATE_KEY_NAME}.pub" ]]; then
    echo "ERROR: Refusing to overwrite existing Flux key files." >&2
    rm -f "$FLUX_SECRET_BACKUP"
    exit 1
fi
trap cleanup EXIT

ssh-keygen -t ed25519 -f "./$FLUX_PRIVATE_KEY_NAME" -N "" -q >/dev/null
flux create secret git flux-system --url=ssh://git@github.com/equinor/radix-flux.git --private-key-file="./$FLUX_PRIVATE_KEY_NAME" --export |
    kubectl --context "$CLUSTER_NAME" apply -f - >/dev/null
FLUX_SECRET_REPLACED=true
SECRET_VALUES=$(<$FLUX_PRIVATE_KEY_NAME)
if EXPIRATION_DATE=$(date -d '+1 year' -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null); then
    :
elif EXPIRATION_DATE=$(date -v+1y -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null); then
    :
else
    echo "ERROR: Unable to compute expiration date: unsupported date implementation." >&2
    exit 1
fi
az keyvault secret set --name "$FLUX_PRIVATE_KEY_NAME" --vault-name "$AZ_RESOURCE_KEYVAULT_CONFIG" --value "$SECRET_VALUES" --expires "$EXPIRATION_DATE" --output none
TODAY_DATE=$(date -u +"%Y-%m-%d")
echo ""
echo ""
echo "You need to manually create a new deploy key in https://github.com/equinor/radix-flux/settings/keys"
echo ""
echo "Name:        $RADIX_ZONE-$TODAY_DATE"
echo "Deploy Key:  $(awk '{print $1, $2}' ./$FLUX_PRIVATE_KEY_NAME.pub)"
echo "Note:        Tick the 'Allow write access' checkbox"
rm -f "./$FLUX_PRIVATE_KEY_NAME" "./$FLUX_PRIVATE_KEY_NAME.pub"
rm -f "$FLUX_SECRET_BACKUP"
trap - EXIT

show_instructions=true
if [[ $USER_PROMPT == true ]]; then
    echo ""
    while true; do
        read -r -p "Do you want me to show the outline how to use the new key in another cluster? (Y/n) " yn
        case $yn in
        [Yy]*) break ;;
        [Nn]*)
            show_instructions=false
            break
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done
fi

if [[ $show_instructions == true ]]; then
  echo ""
  echo "1. Run the following command to download the secret from keyvault and save it to a file named $FLUX_PRIVATE_KEY_NAME"
  echo ""
  echo "az keyvault secret download \\"
  echo "--vault-name "$AZ_RESOURCE_KEYVAULT_CONFIG" \\"
  echo "--name "$FLUX_PRIVATE_KEY_NAME" \\"
  echo "--file "$FLUX_PRIVATE_KEY_NAME" 2>&1 >/dev/null"
  echo ""
  echo ""
  echo "2. Connect to the cluster context:"
  echo "kubectl config use-context <context-name>"
  echo ""
  echo ""
  echo "3. Run the following command to boostrap flux with the new key:"
  echo ""
    echo "kubectl --context <context-name> -n flux-system delete secret flux-system"
  echo ""
  echo "flux bootstrap git \\"
  echo "--private-key-file="$FLUX_PRIVATE_KEY_NAME" \\"
  echo "--url="ssh://git@github.com/equinor/radix-flux" \\"
  echo "--branch="master" \\"
  echo "--path="clusters/$(yq '.flux_folder' <<< "$RADIX_ZONE_YAML")" \\"
  echo "--components-extra=image-reflector-controller,image-automation-controller \\"
  echo "--version=v"$FLUX_VERSION" \\"
  echo "--silent"
  echo ""
  echo ""
  echo "4. After bootstrap is done, delete the file named $FLUX_PRIVATE_KEY_NAME"
  echo ""
  echo "rm $FLUX_PRIVATE_KEY_NAME"
  echo ""
  echo ""
  
fi
echo "Done."