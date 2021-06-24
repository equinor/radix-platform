

#"$(az keyvault secret show --vault-name radix-vault-classic-test --name prometheus-token | jq -r .value)"

#Param(
#    [Parameter(Mandatory)]
#    [string]$sourceVaultName,
#    [Parameter(Mandatory)]
#    [string]$destVaultName
#)

# Dev
Get-AzContext -Name "S941-Omnia-Radix-Development (16ede44b-1f74-40a5-b428-46cca9a5741b) - 3aa4a235-b6e2-48d5-9195-7fcf05b459b0 - MHORV@equinor.com" | Select-AzContext

# Classic
#Get-AzContext -Name "S045-Omnia-Radix-Development-Internal (c44d61d9-1f68-4236-aa19-2103b69766d5) - 3aa4a235-b6e2-48d5-9195-7fcf05b459b0 - MHORV@equinor.com" | Select-AzContext

$sourceVaultName = "radix-vault-dev"
$sourceSubscription = "S941-Omnia-Radix-Development"

$destinationVaultName = "radix-vault-classic-test"
$destinationSubscription = "S045-Omnia-Radix-Development-Internal"

#Connect-AzAccount

$secrets = @()

$secretNames = (Get-AzKeyVaultSecret -VaultName $sourceVaultName).Name
$secretNames.foreach{
    $secrets += ,@($_, (Get-AzKeyVaultSecret -VaultName $sourceVaultName -Name $_).SecretValue)
}

# Switch to omina classic context
Get-AzContext -Name "S045-Omnia-Radix-Development-Internal (c44d61d9-1f68-4236-aa19-2103b69766d5) - 3aa4a235-b6e2-48d5-9195-7fcf05b459b0 - MHORV@equinor.com" | Select-AzContext
$secrets.foreach{
    #Write-Output $_[0]
    #Write-Output $_[1]
    Set-AzKeyVaultSecret -VaultName $destinationVaultName -Name $_[0] -SecretValue $_[1]
}