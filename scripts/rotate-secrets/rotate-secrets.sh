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

# Optional:
# - USER_PROMPT                  : Is human interaction required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env KEY_VAULT="radix-keyv-dev" ./rotate-secrets.sh

#######################################################################################
### START
###


echo ""
echo "Start bootstrap of radix-vulnerability-scanner and radix-vulnerability-scanner-api... "

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
printf "All is good."
echo ""

#######################################################################################
### Set default values for optional input
###

USER_PROMPT=${USER_PROMPT:=true}

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

if [[ -z "$KEY_VAULT" ]]; then
    echo "ERROR: Please provide $KEY_VAULT" >&2
    exit 1
fi


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
echo -e "   -  AZ_RESOURCE_KEYVAULT             : $KEY_VAULT"
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
az keyvault network-rule add --name radix-keyv-dev --ip-address  "$myip" --only-show-errors > /dev/null
printf "Done.\n"

printf "%s► Running scripts... %s%s\n" "${grn}" "$script" "${normal}"

scripts=`ls ./services/*.sh`
for script in $scripts
do

  printf "%s► Execute %s%s\n" "${grn}" "$script" "${normal}"

  (RADIX_ZONE_ENV=${RADIX_ZONE_ENV} KEY_VAULT=${KEY_VAULT} USER_PROMPT=${USER_PROMPT} source $script)
  status=$?
  if [ $status -ne 0 ]; then
    printf "%s💥 Exited with code: %d %s\n" ${red} $status ${normal}
  else
    printf "%s► %s Completed %s\n" ${grn} ${script} ${normal}
  fi;
done

printf "\n%s► Cleaning up... %s\n" "${grn}" "${normal}"
printf "Removing %s to %s firewall... " $myip $KEY_VAULT
az keyvault network-rule add --name radix-keyv-dev --ip-address  "$myip" --only-show-errors > /dev/null
printf "Done.\n"
