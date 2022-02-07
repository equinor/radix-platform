 #!/usr/bin/env bash
 
#######################################################################################
### PURPOSE
###
# Create a custom Access Control role to manage TXT Records
# Check if Role exists, create if not. 
# Optional: Add owners to Role
# Optional: Update Credential secrets
# Optional: Add permissions to Role

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file    sample: ../radix-zone/radix_zone_dev.env

# Optional:           
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.
if [[ -z "$USER_PROMPT" ]]; then
     USER_PROMPT=true
fi
#######################################################################################
### HOW TO USE
###

# NORMAL
# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./app-registration-cert-mananger.sh


#######################################################################################
### START
###
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
normal=$(tput sgr0)
 if [[ -z "$RADIX_ZONE_ENV" ]]; then
    echo "Please provide RADIX_ZONE_ENV" >&2
    exit 1
else
    if [[ ! -f "$RADIX_ZONE_ENV" ]]; then
        echo "RADIX_ZONE_ENV=$RADIX_ZONE_ENV is invalid, the file does not exist." >&2
        exit 1
    fi
    source "$RADIX_ZONE_ENV"
fi
APP_REGISTRATION_CERT_MANAGER="ar-radix-certmanager-${CLUSTER_TYPE}"
APP_ID=$(az ad app list --display-name $APP_REGISTRATION_CERT_MANAGER --query '[].appId' -o tsv)


#######################################################################################
### Verify task at hand
###
echo -e ""
echo -e "Cert-manager app registration:"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  APP_REGISTRATION_CERT_MANAGER     : $APP_REGISTRATION_CERT_MANAGER"
if [ ! -z "$APP_ID" ]; then
echo -e "   -  Exsisting APP_ID                  : $APP_ID";
else
echo -e "   -  Exsisting APP_ID                  : N/A";
fi
echo -e ""
echo -e "   > WHO:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  AZ_SUBSCRIPTION                  : $(az account show --query name -otsv)"
echo -e "   -  AZ_USER                          : $(az account show --query user.name -o tsv)"
echo -e ""
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
fi
echo ""

if [[ $APP_ID == "" ]]; then
    echo "App registration \"$APP_REGISTRATION_CERT_MANAGER\" does not exist."

    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -p "Create app registration? (Y/n) " yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) echo ""; echo "Quitting."; exit 0;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
    printf "Creating app registration..."
    MANIFEST_JSON="manifest.json"
    test -f "$MANIFEST_JSON" && rm "$MANIFEST_JSON"
    cat <<EOF >>${MANIFEST_JSON}
[
    {
        "resourceAppId": "00000003-0000-0000-c000-000000000000",
        "resourceAccess": [
            {
                "id": "e1fe6dd8-ba31-4d61-89e7-88639da4683d",
                "type": "Scope"
            }
        ]
    }
]
EOF
    CREATE_APP_REGISTRATION=$(az ad app create \
        --display-name "${APP_REGISTRATION_CERT_MANAGER}" \
        --required-resource-accesses @${MANIFEST_JSON} 2>&1)
    rm "$MANIFEST_JSON"

    if [[ $CREATE_APP_REGISTRATION == *"ERROR"* ]]; then
        printf " ERROR: Could not create app registration. Make sure you activated the \"Application Developer\" role in PIM.\n"
        exit 1
    else
        printf " Done.\n"
        APP_ID=$(echo $CREATE_APP_REGISTRATION | jq -r '.appId')
    fi
else
    echo "App registration exists."
fi        

#######################################################################################
### Add owners to app registration
###
ADD_OWNERS=true
echo ""
if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Add owners to app registration? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) ADD_OWNERS=false; echo "Skipping."; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ $ADD_OWNERS == true ]]; then
    printf "Adding owners to app registration \"$APP_REGISTRATION_CERT_MANAGER\"..."

    for row in $(az ad group member list --group "Radix" | jq -r '.[] | @base64'); do
        USER_OBJECT_ID=$(echo $row | base64 --decode | jq -r '.objectId')
        USER_PRINCIPAL_NAME=$(echo $row | base64 --decode | jq -r '.userPrincipalName')

        ADD_APP_OWNERS=$(az ad app owner add --id $APP_ID --owner-object-id $USER_OBJECT_ID 2>&1)

        if [[ $ADD_APP_OWNERS == *"ERROR"* ]]; then
            printf " ERROR: Could not add user \"$USER_PRINCIPAL_NAME\" as owner of app registration.\n"
        fi

    done
    printf " Done.\n"
fi

#######################################################################################
### Refresh credential secret
###
CRED_SECRETS=true
echo ""
if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Refresh credential secret? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) CRED_SECRETS=false; echo "Skipping."; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ $CRED_SECRETS == true ]]; then
    printf "Refresh credential secret..."
    APP_DESCRIPTION="Cert-Manager"
    UPDATED_CLIENT_SECRET=$(az ad app credential reset --id "$APP_ID" --credential-description "$APP_DESCRIPTION" 2>/dev/null) # For some reason, description can not be too long.

    if [[ $UPDATED_CLIENT_SECRET == "" ]]; then
        printf " ERROR: Could not refresh client secret for App Registration \"$APP_REGISTRATION_CERT_MANAGER\". Exiting...\n"
        exit 1
    fi
    printf " Done.\n"

    APP_PASSWORD=$(echo $UPDATED_CLIENT_SECRET | jq -r '.password')
    APP_NAME=$(echo $UPDATED_CLIENT_SECRET | jq -r '.name')
    APP_TENANT=$(echo $UPDATED_CLIENT_SECRET | jq -r '.tenant')


    # Get expiration date of updated credential
    EXPIRATION_DATE=$(az ad app credential list --id $APP_ID --query "[?customKeyIdentifier=='$APP_DESCRIPTION'].endDate" --output tsv | sed 's/\..*//')"Z"

    # Create new .json file with updated credential.
    UPDATED_SECRET_VALUES_FILE="updated_secret_values.json"
    test -f "$UPDATED_SECRET_VALUES_FILE" && rm "$UPDATED_SECRET_VALUES_FILE"

    cat <<EOF >>${UPDATED_SECRET_VALUES_FILE}
{
"name": "${APP_REGISTRATION_CERT_MANAGER}",
"id": "${APP_ID}",
"password": "${APP_PASSWORD}",
"description": "${APP_DESCRIPTION}",
"tenantId": "${APP_TENANT}"
}
EOF

    # Update keyvault with secret
    printf "Updating keyvault \"$AZ_RESOURCE_KEYVAULT\"..."
    if [[ $(az keyvault secret set --name "$APP_REGISTRATION_CERT_MANAGER" --vault-name "$AZ_RESOURCE_KEYVAULT" --file "$UPDATED_SECRET_VALUES_FILE" --expires "$EXPIRATION_DATE" 2>&1) == *"ERROR"* ]]; then
        az keyvault secret set --name "$APP_REGISTRATION_CERT_MANAGER" --vault-name "$AZ_RESOURCE_KEYVAULT" --file "$UPDATED_SECRET_VALUES_FILE" --expires "$EXPIRATION_DATE"
        echo -e "\nERROR: Could not update secret in keyvault \"$AZ_RESOURCE_KEYVAULT\". Exiting..."
        exit 1
    fi
    printf " Done\n"

    rm $UPDATED_SECRET_VALUES_FILE
fi

#######################################################################################
### Assign custom permission on TXT records
###
GET_ROLE_DEFINITION_ID () {
  ROLE_DEFINITION_ID=$(az role definition list --query "[?roleName=='$ROLENAME'].name" -otsv)
  wait
}

ROLENAME="DNS TXT Contributor"
GET_ROLE_DEFINITION_ID
CRED_ROLE=true
echo ""
if [[ $ROLE_DEFINITION_ID == "" ]]; then
    echo "Role definition \"$ROLENAME\" does not exist."

    if [[ $USER_PROMPT == true ]]; then
        while true; do
            read -p "Create Role $ROLENAME? (Y/n) " yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) CRED_ROLE=false; echo "Skipping."; break;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

    printf "Creating app registration...\n"

    if [[ $CRED_ROLE == true ]]; then
        CUSTOMDNSROLE_JSON="cert-mananger-custom-dns-role.json"
        test -f "$CUSTOMDNSROLE_JSON" && rm "$CUSTOMDNSROLE_JSON"
        cat <<EOF >>${CUSTOMDNSROLE_JSON}
    {
        "Name": "$ROLENAME",
        "Id": "",
        "IsCustom": true,
        "Description": "Can manage DNS TXT records only.",
        "Actions": [
            "Microsoft.Network/dnsZones/TXT/*",
            "Microsoft.Network/dnsZones/read",
            "Microsoft.Authorization/*/read",
            "Microsoft.Insights/alertRules/*",
            "Microsoft.ResourceHealth/availabilityStatuses/read",
            "Microsoft.Resources/deployments/*",
            "Microsoft.Resources/subscriptions/resourceGroups/read",
            "Microsoft.Support/*"
        ],
        "NotActions": [
        ],
        "AssignableScopes": [
            "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.Network/dnszones/dev.radix.equinor.com",
            "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.Network/dnszones/playground.radix.equinor.com",
            "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/common/providers/Microsoft.Network/dnszones/radix.equinor.com"
        ]
    }
EOF


        CREATE_ROLE=$(az role definition create --role-definition "$CUSTOMDNSROLE_JSON" 2>/dev/null)
        wait
        rm "$CUSTOMDNSROLE_JSON"
        GET_ROLE_DEFINITION_ID
        printf "${red}Waiting${normal}: Waiting for role to be created before next step. 5 seconds pause...\n"
        while [ -z "$ROLE_DEFINITION_ID" ]; do
            sleep 5
            printf "."
            GET_ROLE_DEFINITION_ID
        done
        printf "\n"
        echo "Role created ${grn}OK${normal}"


    fi
else
    echo -e "Role $ROLENAME exists.";
fi
#######################################################################################
### Assign members to role
###
CREATE_ROLE_ASSIGNMENT () {
  ROLE_ASSIGNMENT=$(az role assignment create --assignee "$APP_ID" --role "$ROLENAME" --scope "/subscriptions/${AZ_SUBSCRIPTION_ID}/resourceGroups/${AZ_RESOURCE_GROUP_COMMON}/providers/Microsoft.Network/dnszones/${AZ_RESOURCE_DNS}" 2>/dev/null)
  wait
}

DNSTXT_PERMISSIONS=true
echo ""
if [[ $USER_PROMPT == true ]]; then
    while true; do
        read -p "Assign '$APP_REGISTRATION_CERT_MANAGER' permission to $ROLENAME? (Y/n) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) DNSTXT_PERMISSIONS=false; echo "Skipping."; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ $DNSTXT_PERMISSIONS == true ]]; then
    printf "Assigning permission to app registration...\n"
    CREATE_ROLE_ASSIGNMENT
    printf "${red}Waiting${normal}: Permission not completed. 5 seconds pause before next try...\n"
    while [ -z "$ROLE_ASSIGNMENT" ]; do
            sleep 5
            printf "."
            CREATE_ROLE_ASSIGNMENT
    done
fi
printf "\n"
printf "${grn}Done.${normal}\n"
