Get-Content ./secret.env | ForEach-Object {
  $name, $value = $_.split('=')
}

$secretNamenew=$secretName.ToLower()
$secretExists=(az keyvault secret list --vault-name $destinationVault --query "[?name=='$secretNamenew']" -o tsv) 
if($null -eq $secretExists) {
  write-host "Copy Secret across $secretName"
  az keyvault secret show --vault-name $sourceVault -n $secretName --query "value" -o tsv > secret.txt
  $contenttype=(az keyvault secret show --vault-name $sourceVault -n $secretName --query contentType)
  if ($null -eq $contenttype) {
    az keyvault secret set --vault-name $destinationVault --name $secretNamenew --tags migratedfrom=$sourceVault --file secret.txt
  }
  else {
    az keyvault secret set --vault-name $destinationVault --name $secretNamenew --description $contenttype --tags migratedfrom=$sourceVault --file secret.txt
  }
  az keyvault secret delete --vault-name $sourceVault -n $secretName
  rm secret.txt
}
else {
  write-host "$secretNamenew already exists in $destinationVault"
}
