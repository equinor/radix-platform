#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# - Update the client secret for the "radix-cicd-canary-private-acr" app registration 
# - Update the keyvault secret with the new client secret in multiple keyvaults
# - KEYVAULT_LIST is a comma-separated string of the keyvaults to update


#######################################################################################
### INPUTS
###

# Required:
# - KEYVAULT_LIST       : Comma-separated string of keyvaults to update: "keyvault-1,keyvault-2,keyvault-3"

# Optional:
# - USER_PROMPT         : Is human interaction is required to run script? true/false. Default is true.

#######################################################################################
### HOW TO USE
###

# KEYVAULT_LIST="radix-vault-dev,radix-vault-prod" ./update_auth_secret.sh


#######################################################################################
### START
###

# Required inputs

if [[ -z "$KEYVAULT_LIST" ]]; then
    echo "Please provide KEYVAULT_LIST" >&2
    exit 1
fi

# Optional inputs

if [[ -z "$USER_PROMPT" ]]; then
    USER_PROMPT=true
fi

# Local variables

SECRET_NAME="radix-cicd-canary-values"
APP_REGISTRATION_NAME="radix-cicd-canary-private-acr"

#######################################################################################
### Verify task at hand
###

echo -e ""
echo -e "Update auth secret will use the following configuration:"
echo -e ""
echo -e "   > WHAT:"
echo -e "   -------------------------------------------------------------------"
echo -e "   -  KEYVAULT_LIST                    : $KEYVAULT_LIST"
echo -e "   -  SECRET_NAME                      : $SECRET_NAME"
echo -e "   -  APP_REGISTRATION_NAME            : $APP_REGISTRATION_NAME"
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
fi

echo ""

# Get the existing secret
EXISTING_SECRET_VALUES_FILE="existing_secret_values.yaml"
FIRST_KEYVAULT=${KEYVAULT_LIST%%,*}
FIRST_KEYVAULT="radix-vault-dev"
printf "Getting secret from keyvault \"$FIRST_KEYVAULT\"..."
if [[ ""$(az keyvault secret download --name "$SECRET_NAME" --vault-name "$FIRST_KEYVAULT" --file "$EXISTING_SECRET_VALUES_FILE" 2>&1)"" == *"ERROR"* ]]; then
    echo -e "\nERROR: Could not get secret \"$SECRET_NAME\" in keyvault \"$FIRST_KEYVAULT\". Exiting..."
    exit 1
fi
printf " Done.\n"

# Extract values from existing secret.
IMPERSONATE_USER=$(grep -A1 'impersonate:' $EXISTING_SECRET_VALUES_FILE | grep 'user:' | sed 's/^[user: \]*//')
DEPLOY_KEY_PUBLIC=$(grep -A1 'deployKey:' $EXISTING_SECRET_VALUES_FILE | grep 'public:' | sed 's/^[public: \]*//')
DEPLOY_KEY_PRIVATE=$(grep -A2 'deployKey:' $EXISTING_SECRET_VALUES_FILE | grep 'private:' | sed 's/^[private: \]*//')
DEPLOY_KEY_CANARY_3_PUBLIC=$(grep -A1 'deployKeyCanary3:' $EXISTING_SECRET_VALUES_FILE | grep 'public:' | sed 's/^[public: \]*//')
DEPLOY_KEY_CANARY_3_PRIVATE=$(grep -A2 'deployKeyCanary3:' $EXISTING_SECRET_VALUES_FILE | grep 'private:' | sed 's/^[private: \]*//')
DEPLOY_KEY_CANARY_4_PUBLIC=$(grep -A1 'deployKeyCanary4:' $EXISTING_SECRET_VALUES_FILE | grep 'public:' | sed 's/^[public: \]*//')
DEPLOY_KEY_CANARY_4_PRIVATE=$(grep -A2 'deployKeyCanary4:' $EXISTING_SECRET_VALUES_FILE | grep 'private:' | sed 's/^[private: \]*//')

# Remove temporary file.
rm $EXISTING_SECRET_VALUES_FILE

# Generate new secret for Private Image Hub.
printf "Re-generate client secret for App Registration \"$APP_REGISTRATION_NAME\"..."
APP_REGISTRATION_CLIENT_ID=$(az ad app list --display-name "$APP_REGISTRATION_NAME" | jq -r '.[].appId')

UPDATED_PRIVATE_IMAGE_HUB_PASSWORD=$(az ad app credential reset --id "$APP_REGISTRATION_CLIENT_ID" --credential-description "rdx-cicd-canary" 2>/dev/null | jq -r '.password') # For some reason, description can not be too long.
if [[ -z "$UPDATED_PRIVATE_IMAGE_HUB_PASSWORD" ]]; then
    echo -e "\nERROR: Could not re-generate client secret for App Registration \"$APP_REGISTRATION_NAME\". Exiting..."
    exit 1
fi
printf " Done.\n"

# Create .yaml with new values.
UPDATED_SECRET_VALUES_FILE="updated_secret_values.yaml"
echo "impersonate:
  user: $IMPERSONATE_USER

deployKey:
  public: $DEPLOY_KEY_PUBLIC
  private: $DEPLOY_KEY_PRIVATE

deployKeyCanary3:
  public: $DEPLOY_KEY_CANARY_3_PUBLIC
  private: $DEPLOY_KEY_CANARY_3_PRIVATE

deployKeyCanary4:
  public: $DEPLOY_KEY_CANARY_4_PUBLIC
  private: $DEPLOY_KEY_CANARY_4_PRIVATE

privateImageHub:
  password: $UPDATED_PRIVATE_IMAGE_HUB_PASSWORD
" >> $UPDATED_SECRET_VALUES_FILE

# Update keyvault with new yaml secret for every keyvault in KEYVAULT_LIST
oldIFS=$IFS
IFS=","
for KEYVAULT_NAME in $KEYVAULT_LIST; do
    printf "Updating keyvault \"$KEYVAULT_NAME\"..."
    if [[ ""$(az keyvault secret set --name "$SECRET_NAME" --vault-name "$KEYVAULT_NAME" --file "$UPDATED_SECRET_VALUES_FILE" 2>&1)"" == *"ERROR"* ]]; then
        echo -e "\nERROR: Could not update secret in keyvault \"$KEYVAULT_NAME\"."
        script_errors=true
        continue
    fi
    printf " Done\n"
done
IFS=$oldIFS

# Remove temporary file.
rm $UPDATED_SECRET_VALUES_FILE

if [[ $script_errors == true ]]; then
    echo "Script completed with errors."
else
    echo "Script completed successfully."
fi
