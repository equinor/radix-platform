#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# Move custom ingresses from one cluster to another

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file
# - SOURCE_CLUSTER      : Ex: "test-2", "weekly-93"
# - DEST_CLUSTER        : Ex: "test-2", "weekly-93"

#######################################################################################
### HOW TO USE
###

# Option #1 - migrate ingresses from source to destination cluster
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env SOURCE_CLUSTER="weekly-2" DEST_CLUSTER="weekly-3" ./move_custom_ingresses.sh

# Option #2 - configure ingresses from destination cluster only. Useful when creating cluster form scratch
# RADIX_ZONE_ENV=./radix-zone/radix_zone_dev.env DEST_CLUSTER="weekly-3" ./move_custom_ingresses.sh

#######################################################################################
### START
###
echo ""
echo "Start moving custom ingresses..."

red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for necessary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nERROR: kubectl not found in PATH. Exiting..." >&2
    exit 1
}
hash helm 2>/dev/null || {
    echo -e "\nERROR: helm not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
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

if [[ -z "$DEST_CLUSTER" ]]; then
    echo "ERROR: Please provide DEST_CLUSTER" >&2
    exit 1
fi

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

if [[ -z "$SOURCE_CLUSTER" ]]; then
    echo "ERROR: SOURCE_CLUSTER is not defined" >&2
    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -r -p "Is this intentional? (Y/n) " yn
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
fi

# Source util scripts

source ${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh


LIB_DNS_SCRIPT="${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/dns/lib_dns.sh"
if ! [[ -x "$LIB_DNS_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The lib DNS script is not found or it is not executable in path $LIB_DNS_SCRIPT" >&2
else
    source $LIB_DNS_SCRIPT
fi

#######################################################################################
### Resolve dependencies on other scripts
###

UPDATE_AUTH_PROXY_SECRET_FOR_CONSOLE_SCRIPT="${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/update_auth_proxy_secret_for_console.sh"
if ! [[ -x "$UPDATE_AUTH_PROXY_SECRET_FOR_CONSOLE_SCRIPT" ]]; then
    # Print to stderror
    echo "ERROR: The update auth proxy secret for console script is not found or it is not executable in path $UPDATE_AUTH_PROXY_SECRET_FOR_CONSOLE_SCRIPT" >&2
fi

#######################################################################################
### Define web console auth secret variables
###

AUTH_PROXY_COMPONENT="auth"
AUTH_PROXY_REPLY_PATH="/oauth2/callback"
WEB_COMPONENT="web"
RADIX_WEB_CONSOLE_ENV="prod"
if [[ $CLUSTER_TYPE == "development" ]]; then
    RADIX_WEB_CONSOLE_ENV="qa"
fi
AUTH_INGRESS_SUFFIX=".custom-domain"
WEB_CONSOLE_NAMESPACE="radix-web-console-$RADIX_WEB_CONSOLE_ENV"

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
echo -e "Move custom ingresses will use the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  SOURCE_CLUSTER                   : $SOURCE_CLUSTER"
echo -e "   -  DEST_CLUSTER                     : $DEST_CLUSTER"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

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
    echo ""
fi

#######################################################################################
### Connect kubectl
###

# Exit if cluster does not exist
printf "Connecting kubectl..."
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$DEST_CLUSTER" || {
    # Send message to stderr
    echo -e "ERROR: Cluster \"$DEST_CLUSTER\" not found." >&2
    exit 1
}
printf "...Done.\n"

#######################################################################################
### Verify cluster access
###
verify_cluster_access

#######################################################################################
### Move custom ingresses
###


if [[ -n "${SOURCE_CLUSTER}" ]]; then
    echo ""

    echo ""
    printf "Point to source cluster...\n"
    get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$SOURCE_CLUSTER" >/dev/null
    [[ "$(kubectl config current-context)" != "${SOURCE_CLUSTER}" ]] && exit 1
    printf "Done.\n"

    #######################################################################################
    ### Point grafana to cluster specific ingress
    ###

    printf "Update Auth proxy secret...\n"
    printf "%s► Execute %s%s\n" "${grn}" "$UPDATE_AUTH_PROXY_SECRET_FOR_CONSOLE_SCRIPT" "${normal}"
    (RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER="$DEST_CLUSTER" AUTH_PROXY_COMPONENT="$AUTH_PROXY_COMPONENT" WEB_COMPONENT="$WEB_COMPONENT" WEB_CONSOLE_NAMESPACE="$WEB_CONSOLE_NAMESPACE" AUTH_PROXY_REPLY_PATH="$AUTH_PROXY_REPLY_PATH" source "$UPDATE_AUTH_PROXY_SECRET_FOR_CONSOLE_SCRIPT")
    printf "Done.\n"
    echo ""
fi

echo ""
printf "Point to destination cluster... "
get_credentials "$AZ_RESOURCE_GROUP_CLUSTERS" "$DEST_CLUSTER"
[[ "$(kubectl config current-context)" != "$DEST_CLUSTER" ]] && exit 1


#######################################################################################
### Configure DNS Record to point to new cluster
###

echo ""
printf "Updating DNS zone for %s... " "${AZ_RESOURCE_GROUP_COMMON}"

# Get cluster IP
cluster_ip=$(kubectl get secret --namespace "ingress-nginx" "ingress-nginx-raw-ip" -ojson | jq .data.rawIp --raw-output | base64 --decode)

set -f
a_records=('@' '*' '*.app')
# Create A records in the dns zone
# creating the "@"-record, i.e. e.g. dev.radix.equinor.com.
# creating wildcard record to match all FQDNs in active-cluster ingresses
# creating wildcard record to match all FQDNs in "app alias" ingresses
for record in ${a_records[@]}; do

    printf "%s... " $record
    create-a-record "${record}" "$cluster_ip" "$AZ_RESOURCE_GROUP_COMMON" "$AZ_RESOURCE_DNS" "60" || {
        echo "ERROR: failed to create A record ${record}.${AZ_RESOURCE_DNS}" >&2
    }
done
set +f
printf "Done. \n"


echo ""
printf "Update auth proxy secret and redis cache...\n"
printf "%s► Execute %s%s\n" "${grn}" "$UPDATE_AUTH_PROXY_SECRET_FOR_CONSOLE_SCRIPT" "${normal}"
(RADIX_ZONE_ENV="$RADIX_ZONE_ENV" CLUSTER="$DEST_CLUSTER" AUTH_PROXY_COMPONENT="$AUTH_PROXY_COMPONENT" WEB_COMPONENT="$WEB_COMPONENT" AUTH_INGRESS_SUFFIX="$AUTH_INGRESS_SUFFIX" WEB_CONSOLE_NAMESPACE="$WEB_CONSOLE_NAMESPACE" AUTH_PROXY_REPLY_PATH="$AUTH_PROXY_REPLY_PATH" source "$UPDATE_AUTH_PROXY_SECRET_FOR_CONSOLE_SCRIPT")
wait # wait for subshell to finish

#######################################################################################
### Tag $DEST_CLUSTER to have tag: autostartupschedule="true"
### Used in GHA to determine which cluster shall be powered on daily
###

echo ""
if [[ $CLUSTER_TYPE == "development" ]]; then
    CLUSTERS=$(az aks list -ojson | jq '[{k8s:[.[] | select((.name | startswith("playground") or startswith('\"$DEST_CLUSTER\"') | not) and (.powerState.code!="Stopped") and (.tags.autostartupschedule == null) or (.name == '\"$SOURCE_CLUSTER\"')) | {name: .name, powerstate: .powerState.code, id: .id}]}]')

    while read -r list; do
        CLUSTER=$(jq -n "${list}" | jq -r .name)
        ID=$(jq -n "${list}" | jq -r .id)
        printf "Clear tag 'autostartupschedule' on cluster %s\n" "${CLUSTER}"
        az resource tag \
            --ids "${ID}" \
            --tags autostartupschedule=false \
            --is-incremental
    done < <(printf "%s" "${CLUSTERS}" | jq -c '.[].k8s[]')

    printf "Tag cluster %s to autostartupschedule\n" "${DEST_CLUSTER}"
    az resource tag \
        --ids "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourcegroups/${AZ_RESOURCE_GROUP_CLUSTERS}/providers/Microsoft.ContainerService/managedClusters/${DEST_CLUSTER}" \
        --tags autostartupschedule=true \
        --is-incremental
fi

if [[ -z $CI ]]; then
    echo ""
    echo "###########################################################"
    echo ""
    echo "NOTE: You need to manually activate the cluster"
    echo ""
    echo "You do this in the https://github.com/equinor/radix-flux repo"
    echo ""
    echo "###########################################################"
    echo ""
fi
