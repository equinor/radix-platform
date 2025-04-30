#!/usr/bin/env bash
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)

#######################################################################################
### PURPOSE
###

# This tool looks for all soon to be, or expired secrets and let you rotate them.

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE                   : dev|playground|prod|c2
# - CLUSTER_NAME                 : Ex: "test-2", "weekly-93"

# Optional:
# - UPDATE_SECRETS               : Rotate expired secrets. Defaults to false.
# - FORCE_UPDATE                 : Force Rotate expired secrets. Defaults to false.
# - USER_PROMPT                  : Is human interaction required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE=dev CLUSTER_NAME=weekly-07 UPDATE_SECRETS=true ./rotate-secrets.sh

#######################################################################################
### Read inputs and configs
###

# Required inputs

if [[ $RADIX_ZONE =~ ^(dev|playground|prod|c2)$ ]]
then
    echo "RADIX_ZONE: $RADIX_ZONE"    
else
    echo "ERROR: RADIX_ZONE must be either dev|playground|prod|c2" >&2
    exit 1
fi

#######################################################################################
### Check for prerequisites binaries
###

printf "Loading dependencies... "
source "${RADIX_ZONE_ENV:-'!!!! No RADIX_ZONE_ENV Provided !!!!'}"
source "${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/util.sh"
source "${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/azure-sql/lib_firewall.sh"
source "${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/rotate-secrets/lib_keyvault.sh"
source "${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/azure-sql/lib_security.sh"
source "${RADIX_PLATFORM_REPOSITORY_PATH}/scripts/utility/lib_dependencies.sh"
printf "Done.\n"

assert_cli_tools || exit 1
has_env_name "CLUSTER_NAME" || exit 1
prepare_azure_session || exit 1
setup_cluster_access  "$AZ_RESOURCE_GROUP_CLUSTERS" "$CLUSTER_NAME" ||
  { echo "ERROR: Unable to connect to cluster" >&2; exit 1; }


#######################################################################################
### Set default values for optional input
###

USER_PROMPT=${USER_PROMPT:=true}
UPDATE_SECRETS=${UPDATE_SECRETS:=false}
FORCE_UPDATE=${FORCE_UPDATE:=false}
KEY_VAULT="radix-keyv-${RADIX_ZONE}"
if [[ "${RADIX_ZONE}" == "prod" ]]; then
  KEY_VAULT="radix-keyv-platform"
fi;


#######################################################################################
### Ask user to verify inputs and az login
###

echo -e ""
echo -e "Bootstrap Radix Vulnerability Scanner and API with the following configuration:"
echo -e ""
echo -e "   > WHERE:"
echo -e "   ------------------------------------------------------------------"
echo -e "   -  RADIX_ZONE                       : $RADIX_ZONE"
echo -e "   -  CLUSTER_NAME                     : $CLUSTER_NAME"
echo -e "   -  KEY_VAULT                        : $KEY_VAULT"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  UPDATE_SECRETS                   :  $UPDATE_SECRETS"
echo -e "   -  FORCE_UPDATE                     :  $FORCE_UPDATE"
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""

echo ""

user_prompt_continue || exit 1

#######################################################################################
### Start
###

keyvault_list_secrets "${KEY_VAULT}" "31"
printf "%s► Running scripts... %s%s\n" "${grn}" "$script" "${normal}"

scripts=`ls ./services/*.sh`
for script in $scripts
do

  printf "%s► Execute %s%s\n" "${grn}" "$script" "${normal}"

  (RADIX_ZONE_ENV="${RADIX_ZONE_ENV}" FORCE_UPDATE="${FORCE_UPDATE}" CLUSTER_NAME="${CLUSTER_NAME}" UPDATE_SECRETS="${UPDATE_SECRETS}" KEY_VAULT="${KEY_VAULT}" USER_PROMPT="false" source $script)
  status=$?
  if [ $status -ne 0 ]; then
    printf "%s💥 Exited with code: %d %s\n" ${red} $status ${normal}
  else
    printf "%s► %s Completed %s\n" ${grn} ${script} ${normal}
  fi;
done

keyvault_list_secrets "${KEY_VAULT}" "31"

printf "\n%s► Cleaning up... %s\n" "${grn}" "${normal}"
