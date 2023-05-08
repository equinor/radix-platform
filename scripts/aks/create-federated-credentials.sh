#!/usr/bin/env bash
# Add new Managed identity federated credentials for new cluster to all service principals (both applications and managed identities, available for the user
# ISSUER_URL=<issuer-url> ./create-federated-credentials.sh
#
# Get issuer URL:
# az aks show --resource-group clusters --name <cluster-name> --query oidcIssuerProfile.issuerUrl

tenant="3aa4a235-b6e2-48d5-9195-7fcf05b459b0"

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
  -H "cache-control: no-cache" 2>/dev/null|jq -r '.[].name')
if [[ -z "${appNames}" ]]; then
  printf "ERROR: Could not get applications.\n" >&2
  exit 1
fi

#Get identities for each application
for appName in $appNames
do
  if [[ "$appName" != "radix-test-fed-kv" ]]; then
   # echo "  skip"
    continue
  fi

  envNames=$(curl -X GET \
          "https://api.dev.radix.equinor.com/api/v1/applications/${appName}/environments" \
          -H "Authorization: Bearer ${token}" \
          -H "Content-Type: application/json"  2>/dev/null|jq -r '.[].name')
  if [[ -z "$envNames" ]]; then
    echo "no environments found for an application: $appName"
    continue
  fi

  echo "found environments found for an application: $appName"
  for envName in $envNames
    do
       if [[ "$envName" != "qa" ]]; then
         echo "  temp skip"
         continue
       fi

      identityPropList=($(curl -X GET \
          https://api.dev.radix.equinor.com/api/v1/applications/${appName}/environments/${envName} \
              -H "Authorization: Bearer ${token}" \
              -H "Content-Type: application/json" 2>/dev/null | \
              jq -r '.activeDeployment as $d|select($d != null)|select($d.components != null)|$d.components[] as $c|select($c.identity != null)|select($c.identity.azure != null)|{namespace:$d.namespace,componentName:$c.name,clientId:$c.identity.azure.clientId}'|jq -c '.'))

      if [[ -z "$identityPropList" ]]; then
        echo "- no Azure identities for env: $envName"
        continue
      fi

      echo "- found Azure identities for env: $envName"
      for identityProps in "${identityPropList[@]}"
      do
        namespace=$(echo "$identityProps"|jq -r .namespace)
        componentName=$(echo "$identityProps"|jq -r .componentName)
        clientId=$(echo "$identityProps"|jq -r .clientId)

        sps=$(az ad sp list --filter "appId eq '$clientId'" --query "[].{appId:appId,displayName:displayName,objectId:id,type:servicePrincipalType}"|jq -rc '.|select(length > 0)|.[0]')
        if [[ -z "$sps" ]]; then
          echo "  - not found service principal for the clientId $clientId"
          continue
        fi

        displayName=$(echo "$sps"|jq -r .displayName)
        newFedCredName="$namespace-$componentName-${ISSUER_URL:(-37):36}"
        newFedCredSubject="system:serviceaccount:$namespace:$componentName-sa"
        newFedCredDescription="Generated by script github.com/equinor/radix-platform/scripts/aks/create-federated-credentials.sh on $(date) by $USER"

        if [[ $(echo "$sps"|jq -r '.type') == "Application" ]]; then
          echo "  - application: $displayName, clientId: $clientId, namespace:$namespace, component:$componentName"

          fedCreds=$(az ad app federated-credential list --id "$clientId" -o json|jq -r ".[]|select(.issuer|contains(\"azure.com/$tenant/\"))|select(.subject==\"system:serviceaccount:$namespace:$componentName-sa\")"|jq -s '.')
          if [[ -z "$fedCreds" ]]; then
            echo "fail to get federated credentials"
            exit 1
          elif [ $(echo "$fedCreds"|jq '. | length') -eq 0 ]; then
            echo "  - no federated credential(s) found"
            continue
          fi

          fedCredsCount=$(echo "$fedCreds"|jq -s ".|length")
          echo "  - found $fedCredsCount federated credential(s)"

          requiredFedCredCount=$(echo "$fedCreds"|jq -r ".[]|select(.issuer|contains(\"$ISSUER_URL\"))"|jq -s ".|length")
          if [ "$requiredFedCredCount" -eq 0 ]; then
            echo "    - no federated credentials found for the required issuer - register new one"
            az ad app federated-credential create --id "$clientId" \
              --parameters "{\"audiences\":[\"api://AzureADTokenExchange\"],\"issuer\":\"$ISSUER_URL\",\"name\":\"$newFedCredName\",\"subject\":\"$newFedCredSubject\",\"description\":\"$newFedCredDescription\"}"
#TODO: add error handling
            continue
          fi
          echo "    - found existing federated credential(s) for the required issuer, skip registration"
          continue
        fi

        if [[ $(echo "$sps"|jq -r '.type') == "ManagedIdentity" ]]; then
          echo "  - managed identity: $displayName, clientId: $clientId, namespace:$namespace, component:$componentName"
          resourceGroup=$(az identity list --query "[?clientId=='$clientId']" -o json|jq -r '.|select(length > 0)|.[0]|.resourceGroup')

          echo "  - get federated credentials for the managed identity $displayName in resource group $resourceGroup"
          fedCreds=$(az identity federated-credential list --identity-name "$displayName" --resource-group "$resourceGroup")

          if [[ -z "$fedCreds" ]]; then
            echo "  - fail to get federated credential(s)"
            exit 1
          elif [ $(echo "$fedCreds"|jq '. | length') -eq 0 ]; then
            echo "  - no federated credentials found"
            continue
          fi

          fedCredsCount=$(echo "$fedCreds"|jq -s ".|length")
          echo "  - found $fedCredsCount federated credential(s)"

          requiredFedCredCount=$(echo "$fedCreds"|jq -r ".[]|select(.issuer|contains(\"$ISSUER_URL\"))"|jq -s ".|length")
          if [ "$requiredFedCredCount" -eq 0 ]; then
            echo "    - no federated credential(s) found for the required issuer - register new one"
            #TODO
            az identity federated-credential create \
                --identity-name "$displayName" \
                --resource-group "$resourceGroup" \
                --name "$newFedCredName" \
                --subject "$newFedCredSubject" \
                --issuer "$ISSUER_URL" \
                --audiences "api://AzureADTokenExchange"
#TODO: add error handling
#            if [ $? -ne 0 ]; then
#              echo "Error: Directory not found"
#            fi
            continue
          fi
          echo "    - found existing federated credential(s) for the required issuer, skip registration"
          continue
        fi

        echo "  - not found application or managed identity for the clientId $clientId"
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