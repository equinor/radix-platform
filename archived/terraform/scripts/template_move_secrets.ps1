$secrets = @{}
Get-Content ./keyvaultsecret.env | ForEach-Object {
  $name, $value = $_.split('=')
  $secrets[$name] = $value
}

$secretExists=(az keyvault secret list --vault-name $secrets.destinationVault --query "[?name=='$secrets.newsecretName']" -o tsv) 
if($null -eq $secretExists) {
  write-host "Copy secret" $secrets.oldsecretName "to" $secrets.newsecretName
  az keyvault secret show --vault-name $secrets.sourceVault -n $secrets.oldsecretName --query "value" -o tsv > secret.txt
  $contenttype=(az keyvault secret show --vault-name $secrets.sourceVault -n $secrets.oldsecretName --query contentType)
  if ($null -eq $contenttype) {
    az keyvault secret set --vault-name $secrets.destinationVault --name $secrets.newsecretName --tags migratedfrom=$secrets.sourceVault --file secret.txt
  }
  else {
    az keyvault secret set --vault-name $secrets.destinationVault --name $secrets.newsecretName --description $contenttype --tags migratedfrom=$secrets.sourceVault --file secret.txt
  }
  az keyvault secret delete --vault-name $secrets.sourceVault -n $secrets.oldsecretName
  rm secret.txt
}
else {
  write-host $secrets.newsecretName "already exists in" $secrets.destinationVault
}
