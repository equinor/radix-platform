#!/usr/bin/env bash


keyvault_secret_exist() {
  local keyvault=$1
  local secret=$2

  secret_exists=$(az keyvault secret list --vault-name $keyvault --query "contains([].id, 'https://$keyvault.vault.azure.net/secrets/$secret')" 2> /dev/null)
  if [ $secret_exists == "true" ]; then
    echo 0
  else echo 1;
  fi;
}

keyvault_get_ttl_days() {
  local keyvault=$1
  local secret=$2

  local expiry=$(az keyvault secret show --vault-name $keyvault --name $secret  2> /dev/null | jq '.attributes.expires' -r)
  local dateNow=$(date +%s)
  local dateExpires=$(date -d $expiry +%s)
  local days="$((($dateExpires-$dateNow)/86400))"

  echo $days
}
