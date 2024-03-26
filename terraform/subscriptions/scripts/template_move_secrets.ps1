$sourceVault="<source vault>"
$destinationVault="<destination vault>"
 
$secrets=(az keyvault secret list --vault-name $sourceVault --query "[].{id:id,name:name}") | ConvertFrom-Json | ForEach-Object { 
  $secretName = $_.name
  $secretExists=(az keyvault secret list --vault-name $destinationVault --query "[?name=='$name']" -o tsv)  
  if($secretExists -eq $null) {
    write-host "Copy Secret across $secretName"
    $secretValue=(az keyvault secret show --vault-name $sourceVault -n $secretName --query "value" -o tsv)
    az keyvault secret set --vault-name $destinationVault -n $secretName --value "$secretValue"
  } else {
    write-host "$secretName already exists in $destinationVault"
  } 
} 