#!/usr/bin/env bash


# Refresh credentials for Radix Web Console AAD app and store in keyvault

#######################################################################################
### HOW TO USE
###
#  ./refresh_web_console_app_credentials.sh env


echo ""
echo "Start refreshing credentials for Radix Web Console AAD app... "

printf "Check for neccesary executables... "
hash az 2> /dev/null || { echo -e "\nERROR: Azure-CLI not found in PATH. Exiting... " >&2;  exit 1; }
printf "Done.\n"



# Required inputs

if [[ $1 == "dev" ]]; then
    APP_REGISTRATION="Omnia Radix Web Console - Development"
else
    APP_REGISTRATION="Omnia Radix Web Console - $1"
fi

KEYVAULT="radix-keyv-$1"
SECRETNAME="radix-web-console-auth"

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

cat << EOF
Will use the following configuration:

    -------------------------------------------------------------------
    -  APP Registration    : $APP_REGISTRATION
    -  Key Vault           : $KEYVAULT
    -  Secret              : $SECRETNAME
    -------------------------------------------------------------------
    -  AZ subscription     : $(az account show --query name -otsv)
    -  AZ user             : $(az account show --query user.name -o tsv)
EOF

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

printf "Logging you in to Azure if not already logged in... "
az account show >/dev/null || az login >/dev/null

echo "Generating new app secret for ${APP_REGISTRATION} in Azure AD..."

id="$(az ad app list --filter "displayname eq '${APP_REGISTRATION}'" --output json | jq '.[] | .id' -r)"
password="$(az ad app credential reset --id "${id}" --display-name "web-console" --append --query password --output tsv)"
expiration_date="$(az ad app credential list --id "${id}" --query "sort_by([?displayName=='web-console'], &endDateTime)[-1].endDateTime" --output tsv)"

az keyvault secret set --vault-name "${KEYVAULT}" --name $SECRETNAME --value "${password}" --expires ${expiration_date} 2>&1 >/dev/null

echo "Client secret refreshed and stored in Keyvault: ${KEYVAULT}"
echo "You want to run update_auth_proxy_secret_for_console.sh to update secrets in cluster"
