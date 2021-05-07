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

if [[ -z "$CLUSTER_NAME" ]]; then
    echo "Please provide CLUSTER_NAME" >&2
    exit 1
fi

# Get secrets: api-url and tenant-token from keyvault
DYNATRACE_API_URL=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-api-url | jq -r .value)
DYNATRACE_API_TOKEN=$(az keyvault secret show --vault-name "$AZ_RESOURCE_KEYVAULT" --name dynatrace-tenant-token | jq -r .value)

# Get the credential ID from Dynatrace API (Radix-dev, Radix-playground or Radix-prod)
CREDENTIAL_ID="$(curl --request GET \
    --url $DYNATRACE_API_URL/config/v1/kubernetes/credentials \
    --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
    --silent | jq -r '.values[] | select(.name=="Radix-'$RADIX_ZONE'").id')"

if [[ -z "$CREDENTIAL_ID" ]]; then
    echo "Credential does not exist." >&2
    exit 1
fi

# Use the credential ID to get the current api-url from the Kubernetes Credential. This is what we will be changing from.
CREDENTIAL_URL="$(curl --request GET \
    --url $DYNATRACE_API_URL/config/v1/kubernetes/credentials/$CREDENTIAL_ID \
    --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
    --silent | jq --raw-output '.endpointUrl')"

# Get the cluster api-url from Azure. This is what we will be changing to.
CLUSTER_API_URL="$(kubectl config view --minify -o json | jq --raw-output '.clusters[0].cluster.server' | sed "s :443 / ")" ###### this should be available if AKS cluster is available.

# Check if the current Kubernetes Credential api-url matches the api-url from Azure
if [[ $CREDENTIAL_URL != $CLUSTER_API_URL ]]; then

    echo "Credentials outdated. Validating PUT-request.."

    # Get the auth token stored in a secret in the dynatrace service agent for kubernetes monitoring. 
    AUTH_TOKEN="$(kubectl get secret $(kubectl get sa dynatrace-kubernetes-monitoring -o jsonpath='{.secrets[0].name}' -n dynatrace) -o jsonpath='{.data.token}' -n dynatrace | base64 --decode)"

    VALIDATE_REQUEST="$(curl --request POST \
    --url $DYNATRACE_API_URL/config/v1/kubernetes/credentials/$CREDENTIAL_ID/validator \
    --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
    --header 'Content-Type: application/json' \
    --data '{
        "label": "Radix Dev-test",
        "endpointUrl": "'$CLUSTER_API_URL'"
    }' \
    --write-out '%{http_code}' | jq --raw-output)"

    if [[ $VALIDATE_REQUEST == 204 ]]; then
        echo "Validation successful. Updating credentials.."

        UPDATE_CREDENTIALS="$(curl --request PUT \
        --url $DYNATRACE_API_URL/config/v1/kubernetes/credentials/$CREDENTIAL_ID \
        --header 'Authorization: Api-Token '$DYNATRACE_API_TOKEN \
        --header 'Content-Type: application/json' \
        --data '{
            "label": "Radix Dev",
            "endpointUrl": "'$CLUSTER_API_URL'"
        }' \
        --write-out '%{http_code}' | jq --raw-output)"

        if [[ $UPDATE_CREDENTIALS =~ (201|204) ]]; then
            echo "Credentials updated."
        else
            echo "Error while updating credentials."
            echo $UPDATE_CREDENTIALS | jq .
        fi
    else
        echo "Error while validating request."
        echo $VALIDATE_REQUEST | jq .
    fi
    
fi
echo "Done."