#!/bin/bash

#######################################################################################
### PURPOSE
###
# - Patch all RadixDeployments to use the new Azuer Container Registry after Velero Restore

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE          : dev|playground|prod|c2|c3
# - SOURCE_ACR          : Source ACR login server (e.g., radixc2prod.azurecr.io)
# - TARGET_ACR          : Target ACR login server (e.g., radixc3.azurecr.io)

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2|c3)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2|c3" >&2
    exit 1
fi

if [[ -z "$SOURCE_ACR" ]]; then
    echo "ERROR: Please provide SOURCE_ACR" >&2
    exit 1
fi

if [[ -z "$TARGET_ACR" ]]; then
    echo "ERROR: Please provide TARGET_ACR" >&2
    exit 1
fi

# Source util scripts
RADIX_PLATFORM_REPOSITORY_PATH=$(git rev-parse --show-toplevel)
source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh

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

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"


#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Update acr on active Radix Deployments:"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  SOURCE_ACR             : $SOURCE_ACR"
echo -e "   -  TARGET_ACR             : $TARGET_ACR"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Is this correct? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo ""; echo "Quitting."; exit 0;;
            * ) echo "Please answer yes or no.";;
        esac
    done
    echo ""
fi

echo "Patching RadixDeployments to replace '${SOURCE_ACR}' with '${TARGET_ACR}'..."
echo ""

# Get all active RadixDeployments
radixdeployments=$(kubectl get rd -A -o jsonpath='{range .items[?(@.status.condition=="Active")]}{.metadata.name}{" "}{.metadata.namespace}{"\n"}{end}')

if [ -z "$radixdeployments" ]; then
    echo "No active RadixDeployments found."
    exit 0
fi

count=0
while IFS= read -r line; do
    rd_name=$(echo "$line" | awk '{print $1}')
    rd_namespace=$(echo "$line" | awk '{print $2}')
    
    if [ -z "$rd_name" ] || [ -z "$rd_namespace" ]; then
        continue
    fi
    
    echo "Processing: $rd_name in namespace $rd_namespace"
    
    # Get the current RadixDeployment spec
    kubectl get rd "$rd_name" -n "$rd_namespace" -o json | \
    jq --arg search "$SOURCE_ACR" --arg replace "$TARGET_ACR" '
        # Update images in all components
        .spec.components[]?.image |= sub($search; $replace) |
        # Update images in all jobs
        .spec.jobs[]?.image |= sub($search; $replace)
    ' | kubectl apply -f -
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Successfully patched $rd_name"
        ((count++))
    else
        echo "  ✗ Failed to patch $rd_name"
    fi
    echo ""
done <<< "$radixdeployments"

echo "Completed: Patched $count RadixDeployments"
