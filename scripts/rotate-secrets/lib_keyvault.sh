#!/usr/bin/env bash


keyvault_secret_exist() {
  local keyvault=$1
  local secretName=$2

  secret_exists=$(az keyvault secret list --vault-name $keyvault --query "contains([].id, 'https://$keyvault.vault.azure.net/secrets/$secretName')" 2> /dev/null)
  if [ $secret_exists == "true" ]; then
    echo 0
  else echo 1;
  fi;
}

keyvault_secret_ttl_days() {
  local keyvault=$1
  local secretName=$2

  local expiry=$(az keyvault secret show --vault-name $keyvault --name $secretName  2> /dev/null | jq '.attributes.expires' -r)
  local dateNow=$(date +%s)
  local dateExpires=$(date -d $expiry +%s)
  local days="$((($dateExpires-$dateNow)/86400))"

  echo $days
}

keyvault_secret_save() {
  local keyvault=$1
  local secretName=$2
  local value=$3

  local expiry=$(date -d "+365 days")
  local notBefore=$(date -d "-5 minutes")
  az keyvault secret set --vault-name $keyvault --name $secretName --value $password --not-before $notBefore --expires $expiry --output none --only-show-errors ||
      { echo "ERROR: Could not get secret '$secretName' in '${keyvault}'." >&2; return 1; }
}
