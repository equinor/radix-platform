#!/usr/bin/env bash

echo ""
printf "Check for necessary executables... "

#az login --use-device-code
#../radix-cli/rrx get application -c development -o json|jq -r .name
token=$(az account get-access-token --resource 6dae42f8-4368-4678-94ff-3960e28e3630|jq -r .accessToken)

#using curl request json from api with bearer authorization token. Save json to env variable
appNames=$(curl -X GET \
  https://api.dev.radix.equinor.com/api/v1/applications \
  -H "Authorization: Bearer ${token}" \
  -H "Content-Type: application/json" \
  -H "cache-control: no-cache" 2>/dev/null |jq -r '.[].name')

identityEntries=()
for appName in $appNames
do
  echo "--- app: $appName"
  envNames=$(curl -X GET \
          "https://api.dev.radix.equinor.com/api/v1/applications/${appName}/environments" \
          -H "Authorization: Bearer ${token}" \
          -H "Content-Type: application/json"  2>/dev/null |jq -r '.[].name')
  for envName in $envNames
    do
      echo "---- env: $envName"
      identityPropList=$(curl -X GET \
              "https://api.dev.radix.equinor.com/api/v1/applications/${appName}/environments/${envName}" \
              -H "Authorization: Bearer ${token}" \
              -H "Content-Type: application/json" 2>/dev/null | \
              jq -r '.activeDeployment as $i | select($i.components != null)| $i.components[] as $c|select($c.identity != null)|select($c.identity.azure != null)|{"ns":$i.namespace, "componentName":$c.name,"clientId":$c.identity.azure.clientId}')
      if [[ -z "$identityPropList" ]]; then
        echo "------ no identity found"
      else
        identityEntries+=("$identityPropList")
      fi
    done
done

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

echo "Identity entries:"
for identityEntry in "${identityEntries[@]}"
do
  echo "$identityEntry"
done


#a='{"ns": "radix-test-fed-kv-dev","componentName": "app2","clientId": "7ef841f8-a263-45ea-8993-683cc6817ae2"}'