#!/usr/bin/env bash

#######################################################################################
### PURPOSE
###

# - Update the client secret for the "radix-cicd-canary-private-acr" app registration 
# - Update the keyvault secret with the new client secret


#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file


#######################################################################################
### HOW TO USE
###

# RADIX_ZONE_ENV=../radix-zone/radix_zone_dev.env ./update_auth_secret.sh


#######################################################################################
### START
###

# Local variables
SECRET_NAME="radix-cicd-canary-values"
APP_REGISTRATION_NAME="radix-cicd-canary-private-acr"

# Get the existing secret
EXISTING_SECRET_VALUES_FILE="existing_secret_values.yaml"
az keyvault secret download \
    --name "$SECRET_NAME" \
    --vault-name "$AZ_RESOURCE_KEYVAULT" \
    --file "$EXISTING_SECRET_VALUES_FILE"

# Extract values from existing secret.
IMPERSONATE_USER=$(grep -A1 'impersonate:' $EXISTING_SECRET_VALUES_FILE | grep 'user:' | sed 's/user: //')
DEPLOY_KEY_PUBLIC=$(grep -A1 'deployKey:' $EXISTING_SECRET_VALUES_FILE | grep 'public:' | sed 's/^[public: \]*//')
DEPLOY_KEY_PRIVATE=$(grep -A2 'deployKey:' $EXISTING_SECRET_VALUES_FILE | grep 'private:' | sed 's/^[private: \]*//')
DEPLOY_KEY_CANARY_3_PUBLIC=$(grep -A1 'deployKeyCanary3:' $EXISTING_SECRET_VALUES_FILE | grep 'public:' | sed 's/^[public: \]*//')
DEPLOY_KEY_CANARY_3_PRIVATE=$(grep -A2 'deployKeyCanary3:' $EXISTING_SECRET_VALUES_FILE | grep 'private:' | sed 's/^[private: \]*//')
DEPLOY_KEY_CANARY_4_PUBLIC=$(grep -A1 'deployKeyCanary4:' $EXISTING_SECRET_VALUES_FILE | grep 'public:' | sed 's/^[public: \]*//')
DEPLOY_KEY_CANARY_4_PRIVATE=$(grep -A2 'deployKeyCanary4:' $EXISTING_SECRET_VALUES_FILE | grep 'private:' | sed 's/^[private: \]*//')

# Generate new secret for Private Image Hub.
APP_REGISTRATION_CLIENT_ID=$(az ad app list --display-name "$APP_REGISTRATION_NAME" | jq -r '.[].appId')
UPDATED_PRIVATE_IMAGE_HUB_PASSWORD=$(az ad app credential reset --id "$APP_REGISTRATION_CLIENT_ID" --credential-description "rdx-cicd-canary" | jq -r '.password') # For some reason, description can not be too long.

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

# Update keyvault with new yaml secret
az keyvault secret set \ 
    --name="$SECRET_NAME" \
    --vault-name="$AZ_RESOURCE_KEYVAULT" \
    --file="$UPDATED_SECRET_VALUES_FILE" \
    2>&1 >/dev/null

# Remove temporary files.
rm $EXISTING_SECRET_VALUES_FILE
rm $UPDATED_SECRET_VALUES_FILE
