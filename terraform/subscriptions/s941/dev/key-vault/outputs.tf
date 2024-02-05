output "data" {
  value = module.keyvault.data
}

output "vault_id" {
  value = module.keyvault.data.vault_id

}