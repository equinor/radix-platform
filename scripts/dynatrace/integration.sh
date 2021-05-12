#!/bin/bash

#######################################################################################
### PURPOSE
###

# After base components have been installed and Dynatrace has been deployed, connect the cluster to Dynatrace by updating the
# kubernetes credentials using the Dynatrace API.

#######################################################################################
### PRECONDITIONS
###

# - AKS cluster is available
# - User has role cluster-admin
# - Dynatrace has been deployed

#######################################################################################
### INPUTS
###

# Required:
# - RADIX_ZONE_ENV      : Path to *.env file

#######################################################################################
### START
###

echo ""
echo "Start update of Kubernetes credentials in Dynatrace..."

#######################################################################################
### Check for prerequisites binaries
###

echo ""
printf "Check for neccesary executables... "
hash az 2>/dev/null || {
    echo -e "\nError: Azure-CLI not found in PATH. Exiting..."
    exit 1
}
hash kubectl 2>/dev/null || {
    echo -e "\nError: kubectl not found in PATH. Exiting..."
    exit 1
}
hash jq 2>/dev/null || {
    echo -e "\nError: jq not found in PATH. Exiting..."
    exit 1
}
printf "All is good."
echo ""

#######################################################################################
### Read inputs and configs
###

# Required inputs

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

# Get secrets: api-url and tenant-token from keyvault
DYNATRACE_API_URL=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-api-url | jq -r .value)
DYNATRACE_API_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-tenant-token | jq -r .value)

# Get the cluster api-url from Azure. This is what we will be changing to.
CLUSTER_API_URL="$(kubectl config view --minify -o json | jq --raw-output '.clusters[0].cluster.server' | sed "s :443 / ")"

# Get the credential ID from Dynatrace API (Radix-dev, Radix-playground or Radix-prod)
CREDENTIAL_ID="$(curl --request GET \
    --url $DYNATRACE_API_URL/config/v1/kubernetes/credentials \
    --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
    --silent | jq -r '.values[] | select(.name=="Radix-'$RADIX_ZONE'").id')"

# Check for existing credential
if [[ "$CREDENTIAL_ID" ]]; then
    # Check if existing credential is outdated
    CREDENTIAL_URL="$(curl --request GET \
        --url $DYNATRACE_API_URL/config/v1/kubernetes/credentials/$CREDENTIAL_ID \
        --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
        --silent | jq --raw-output '.endpointUrl')"

    if [[ $CREDENTIAL_URL != $CLUSTER_API_URL ]]; then
        echo "Existing credential outdated, deleting it..." $CREDENTIAL_ID
        DELETE_CREDENTIAL="$(curl --request DELETE \
            --url $DYNATRACE_API_URL/config/v1/kubernetes/credentials/$CREDENTIAL_ID \
            --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
        --silent \
        --write-out '%{http_code}' | jq --raw-output)"
        
        if [[ $DELETE_CREDENTIAL == 204 ]]; then
            echo "Credential deleted."
        else
            echo "Error deleting credential"
            echo $DELETE_CREDENTIAL | jq .
        fi
    else
        # Existing credenital is valid
        echo "Credential already exists."
        exit 0
    fi
fi

    # Get the auth token stored in a secret in the dynatrace service agent for kubernetes monitoring. 
    AUTH_TOKEN="$(kubectl get secret $(kubectl get sa dynatrace-kubernetes-monitoring -o jsonpath='{.secrets[0].name}' -n dynatrace) -o jsonpath='{.data.token}' -n dynatrace | base64 --decode)"

# Validate request
echo "Validating request for credential creation..."
VALIDATE_CREATE="$(curl --request POST \
    --url $DYNATRACE_API_URL/config/v1/kubernetes/credentials/validator \
    --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
    --header 'Content-Type: application/json' \
    --data '{
        "label": "Radix-'$RADIX_ZONE'",
        "endpointUrl": "'$CLUSTER_API_URL'",
        "authToken": "'$AUTH_TOKEN'"
    }' \
    --silent \
    --write-out '%{http_code}' | jq --raw-output)"
if [[ $VALIDATE_CREATE == 204 ]]; then
    echo "Validation successful, creating new credential..."

    CREDENTIAL_ID="$(curl --request POST \
        --url $DYNATRACE_API_URL/config/v1/kubernetes/credentials \
        --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
        --header 'Content-Type: application/json' \
        --data '{
            "label": "Radix-'$RADIX_ZONE'",
            "endpointUrl": "'$CLUSTER_API_URL'",
            "authToken": "'$AUTH_TOKEN'"
        }' \
        --silent | jq --raw-output '.id')"

    if [[ $VALIDATE_CREATE == 201 ]]; then
        echo "Credential successfully created."
        fi
    else
    # Validation failed.
    echo "Validation of create request failed."
    echo $VALIDATE_CREATE | jq .
fi
echo "Done."