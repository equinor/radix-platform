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
# - RADIX_ZONE_ENV               : Path to *.env file
# - CLUSTER_NAME                 : Ex: "test-2", "weekly-93"

# Optional:
# - UPDATE_SECRETS               : Rotate expired secrets. Defaults to false.
# - USER_PROMPT                  : Is human interaction required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env CLUSTER_NAME=weekly-07 UPDATE_SECRETS=false ./rotate-secrets.sh

#######################################################################################
### START
###


echo ""
echo "Start checking secrets in keyvault... "

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nERROR: Azure-CLI not found in PATH. Exiting..." >&2
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nERROR: jq not found in PATH. Exiting..." >&2
    exit 1
}
printf "Done.\n"

#######################################################################################
### Set default values for optional input
###

KEY_VAULT="radix-keyv-${RADIX_ZONE}"
if [[ "${RADIX_ZONE}" == "prod" ]]; then
  KEY_VAULT="radix-keyv-platform"
fi;
USER_PROMPT=${USER_PROMPT:=true}
UPDATE_SECRETS=${UPDATE_SECRETS:=true}

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

case UPDATE_SECRETS in
    true|false) ;;
    *)
        echo 'ERROR: UPDATE_SECRETS must be true or false' >&2
        exit 1
        ;;
esac

#######################################################################################
### Prepare az session
###

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null
az account set --subscription "$AZ_SUBSCRIPTION_ID" >/dev/null
printf "Done.\n"

script_dir_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
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
            [Nn]* ) echo ""; echo "Quitting."; exit 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

#######################################################################################
### Start
###

printf "initializing...\n"
printf "Getting public ip... "
myip=$(curl http://ifconfig.me/ip 2> /dev/null) ||
{ echo "ERROR: Failed to get IP address." >&2; exit 1; }
printf "Done.\n"

printf "Adding %s to %s firewall... " $myip $KEY_VAULT
az keyvault network-rule add --name "${KEY_VAULT}" --ip-address  "$myip" --only-show-errors > /dev/null
printf "Done.\n"

printf "%s► Running scripts... %s%s\n" "${grn}" "$script" "${normal}"

scripts=`ls ./services/*.sh`
for script in $scripts
do

  printf "%s► Execute %s%s\n" "${grn}" "$script" "${normal}"

  (RADIX_ZONE_ENV=${RADIX_ZONE_ENV} CLUSTER_NAME=${CLUSTER_NAME} UPDATE_SECRETS=${UPDATE_SECRETS} KEY_VAULT=${KEY_VAULT} USER_PROMPT=${USER_PROMPT} source $script)
  status=$?
  if [ $status -ne 0 ]; then
    printf "%s💥 Exited with code: %d %s\n" ${red} $status ${normal}
  else
    printf "%s► %s Completed %s\n" ${grn} ${script} ${normal}
  fi;
done

printf "\n%s► Cleaning up... %s\n" "${grn}" "${normal}"
printf "Removing %s to %s firewall... " $myip $KEY_VAULT
az keyvault network-rule add --name "${KEY_VAULT}" --ip-address  "$myip" --only-show-errors > /dev/null
printf "Done.\n"
