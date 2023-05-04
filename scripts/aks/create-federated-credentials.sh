#!/usr/bin/env bash
# Add new Managed identity federated credentials for new cluster to all service principals (both applications and managed identities, available for the user
# ISSUER_URL=<issuer-url> ./create-federated-credentials.sh
#
# Get issuer URL:
# az aks show --resource-group clusters --name <cluster-name> --query oidcIssuerProfile.issuerUrl

if [[ -z "${ISSUER_URL}" ]]; then
  printf "ERROR: ISSUER_URL is not set.\n" >&2
  exit 1
fi

#az login --use-device-code
#../radix-cli/rrx get application -c development -o json|jq -r .name
echo "Get an access token"
token=$(az account get-access-token --resource 6dae42f8-4368-4678-94ff-3960e28e3630|jq -r .accessToken)
if [[ -z "${token}" ]]; then
  printf "ERROR: Could not get access token.\n" >&2
  exit 1
fi

#Get available Radix applications
appNames=$(curl -X GET \
  https://api.dev.radix.equinor.com/api/v1/applications \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  -H "cache-control: no-cache" 2>/dev/null |jq -r '.[].name')
if [[ -z "${appNames}" ]]; then
  printf "ERROR: Could not get applications.\n" >&2
  exit 1
fi

#Get identities for each application
for appName in $appNames
do
  #echo "App: $appName"
  if [[ "$appName" != "radix-test-fed-kv" ]]; then
   # echo "  skip"
    continue
  fi

  envNames=$(curl -X GET \
          "https://api.dev.radix.equinor.com/api/v1/applications/${appName}/environments" \
          -H "Authorization: Bearer ${token}" \
          -H "Content-Type: application/json"  2>/dev/null |jq -r '.[].name')
  if [[ -z "$envNames" ]]; then
    echo " no environments found"
    continue
  fi
  for envName in $envNames
    do
      # if [[ "$envName" != "dev" ]]; then
      #   echo "  skip"
      #   continue
      # fi

      identityPropList=($(curl -X GET \
          https://api.dev.radix.equinor.com/api/v1/applications/${appName}/environments/${envName} \
              -H "Authorization: Bearer ${token}" \
              -H "Content-Type: application/json" 2>/dev/null | \
              jq -r '.activeDeployment as $d|select($d != null)|select($d.components != null)|$d.components[] as $c|select($c.identity != null)|select($c.identity.azure != null)|{namespace:$d.namespace,componentName:$c.name,clientId:$c.identity.azure.clientId}'|jq -c '.'))

      if [[ -z "$identityPropList" ]]; then
        echo "  no Azure identities for env: $envName"
        continue
      fi

      echo "  found Azure identities for env: $envName"
      for identityProps in "${identityPropList[@]}"
      do
        namespace=$(echo "$identityProps"|jq -r .namespace)
        componentName=$(echo "$identityProps"|jq -r .componentName)
        clientId=$(echo "$identityProps"|jq -r .clientId)
        echo "namespace:$namespace, component:$componentName, clientId: $clientId"

        sps=$(az ad sp list --filter "appId eq '$clientId'" --query "[].{appId:appId,displayName:displayName,objectId:id,type:servicePrincipalType}"|jq -rc '.|select(length > 0)|.[0]')
        if [[ -z "$sps" ]]; then
          echo "not found service principal for the clientId $clientId"
          continue
        fi

        if [[ $(echo "$sps"|jq -r '.type') == "Application" ]]; then
          echo "clientId $clientId is an application: $sps"
          #TODO: add federated credentials
          continue
        elif [[ $(echo "$sps"|jq -r '.type') == "ManagedIdentity" ]]; then
          echo "clientId $clientId is a managed identity: $sps"
          #TODO: add federated credentials
          continue
        fi

        echo "not found application or managed identity for the clientId $clientId"
      done
    done
done

echo "completed"

#az ad app federated-credential list --id 7ef841f8-a263-45ea-8993-683cc6817ae2 -o json
#az identity federated-credential list --identity-name serg-delete-me -g test-resources -o json

#az resource list --query "[?type=='Microsoft.ManagedIdentity/userAssignedIdentities' && identity == null]" -o json
#az ad sp list --show-mine --query "[].{appId:appId,displayName:displayName,objectId:id,type:servicePrincipalType}"
#  {
#    "appId": "7ef841f8-a263-45ea-8993-683cc6817ae2",
#    "displayName": "ar-radix-csi-az-keyvault",
#    "objectId": "aee13272...",
#    "type": "Application"
#  },

#az ad sp show --id aee13272-...
#"servicePrincipalType": "Application

#az ad sp show --id c5a65135-...
#"servicePrincipalType": "ManagedIdentity"

#az ad sp list --show-mine --query "[?id=='c5a65135-...'][].{appId:appId,displayName:displayName,objectId:id,type:servicePrincipalType}"

#echo "Identity entries:"
#for identityEntry in "${identityEntries[@]}"
#do
#  echo "$identityEntry"
#done


#a='{"ns": "radix-test-fed-kv-dev","componentName": "app2","clientId": "7ef841f8-a263-45ea-8993-683cc6817ae2"}'