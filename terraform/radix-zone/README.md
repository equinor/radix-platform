# DR:

**Pre-requisites**  
Make sure you have the role **"Application Developer"** and is **"Owner"** on the subscription before starting.  
Ensure you have all tools installed -list of tools required (list in radix-private)


# Recover tasks

## 1 - **Check** what can be recovered/restored

- keyvaults
- databases
- storage accounts

## 2 - Create Infrastructure
`Comment out backend "azurerm" {} to run local`  

### 2-A - Create Resource group
terraform/infrastructure/s941/dev/resourcegroups/main.tf # local  

### 2-B - Recover/Restore
Restore/Recover keyvaults, storage accounts, databases  

### 2-C - Bootstrap bas infrastructure
Remember to activate application developer role, and re-authorize azure again  
```
scripts/radix-zone/base-infrastructure/bootstrap.sh  
```
Read all comments and warnings, in case of freeze, Ctrl + C **only once**
- Check ACR, add your IP in Networking
- Import ACR images from a existing ACR  

### 2-D - Create Resources
terraform/oidc/rbac/main.tf - [readme](../oidc/rbac/readme.md) # local  
terraform/infrastructure/s941/dev/keyvaults/main.tf [readme](../infrastructure/s941/dev/keyvaults/readme.md) # local  
terraform/infrastructure/s941/dev/storageaccounts/main.tf - [readme](../infrastructure/s941/dev/storageaccounts/readme.md) # local  

## 3 - Create Resources with secrets

### 3-A - Update variables
change values in .env files:
```
resource_group_name="s612-tfstate"
storage_account_name ="s612radixinfra"
client_id="github maintenance clientid"
client_secret="github maintenance secret"
subscription_id="DR subscription"
```
in:
- terraform/infrastructure/s941/dev/networkmanager/main.tf  
- terraform/infrastructure/s941/dev/sqldatabases/main.tf  
- terraform/infrastructure/s941/dev/mysql/main.tf  

### 3-B - Create/Bootstrap resources

terraform/infrastructure/s941/dev/networkmanager/main.tf  
```
scripts/service-principals-and-aad-apps/refresh_web_console_app_credentials.sh
```
```
scripts/velero/bootstrap.sh
```
```
scripts/radix-zone/monitoring-infrastructure/bootstrap.sh
```
```
terraform/infrastructure/s941/dev/sqldatabases/main.tf
```
 - [readme](../infrastructure/s941/dev/sqldatabases/readme.md)  

move state file to azure with sync.sh #TODO update how

## 4 - Bootstrap AKS
```
scripts/aks/bootstrap.sh
```
[readme](../scripts/aks/readme.md)

## 5 - Generate secrets
radix-cost-allocation-db-admin  
```
password=$(openssl rand -base64 32 | tr -- '+/' '-_')  
az keyvault secret set --vault-name "radix-vault-dev-dr2" --name "radix-cost-allocation-db-admin" --value "${password}"  
```
    
radix-vulnerability-scan-db-admin  
```
password=$(openssl rand -base64 32 | tr -- '+/' '-_')  
az keyvault secret set --vault-name "radix-vault-dev-dr2" --name "radix-vulnerability-scan-db-admin" --value "${password}"  
```
    
mysql-grafana-dev-admin-password  
```
password=$(openssl rand -base64 32 | tr -- '+/' '-_')  
az keyvault secret set --vault-name "radix-monitoring-dev-dr" --name "mysql-grafana-dev-admin-password" --value "${password}"  
```
    
s612-radix-grafana-dev-mysql-admin-pwd  
```
password=$(openssl rand -base64 32 | tr -- '+/' '-_')  
az keyvault secret set --vault-name "radix-monitoring-dev-dr" --name "s612-radix-grafana-dev-mysql-admin-pwd" --value "${password}"  
```
    
grafana-database-password  
```
password=$(openssl rand -base64 32 | tr -- '+/' '-_')  
az keyvault secret set --vault-name "radix-monitoring-dev-dr" --name "grafana-database-password" --value "${password}"  
```
## 6 - Create SQL database for Grafana

terraform/infrastructure/s941/dev/mysql/main.tf - [readme](../infrastructure/s941/dev/mysql/readme.md)  
> terraform / acr (**untested at this stage**) (Comment out `azurerm_private_dns_a_record` on the first run, run it over again with it included)

## 7 - Create ACR

terraform/infrastructure/s941/dev/acr/main.tf - [readme](../terraform/infrastructure/s941/dev/acr/readme.md)  

## 8 - Install base components
```
OVERRIDE_GIT_BRANCH=dr-test scripts/install_base_components.sh  
```
[readme](../../scripts/readme.md#step-3-deploy-base-components)  

***Wait for Flux to do it's things***

## 8 - Optional Components
```
scripts/vulnerability-scanner/bootstrap.sh REGENERATE_SCANNER_PASSWORD=true REGENERATE_API_PASSWORD=true  
    radix-vulnerability-scan-db-writer-dev  
    radix-vulnerability-scan-db-api-dev  
scripts/cost-allocation/bootstrap.sh REGENERATE_API_PASSWORD=true REGENERATE_COLLECTOR_PASSWORD=true  
    radix-cost-allocation-db-api-dev  
    radix-cost-allocation-db-writer-dev  
```

## Manual steps...

### 1 - Configure firewall for ACR
Added AKS Public egress ip to main ACR  

(For DR test DNS zone needs to be updated)

### 2 - secrets (TODO)
acr-whitelist-ips-dev  
flux-github-deploy-key-public (manually copy this to radix-flux github repo)  
slack-webhook-dev  
radix-cicd-canary-values   

### 3 - Grafana
**TODO How to create a backup of Grafana**  
Scale grafana to 0 pods while restoring db  
```
CREATE USER 'grafana'@'%' IDENTIFIED BY 'new_password';  
GRANT ALL ON grafana.* TO 'grafana'@'%';
```
Use MySQL Workbench to transfer db from other instance to new, or figure out a way to allow restore db to different subscription  
Scale grafana to 2 pods when done  

### 4 - Restore Velero backup
Download existing backup:  
```
`az storage blob download-batch  --account-name s941radixvelerodev --destination ./backup --pattern "backups/all-hourly-20231219090009/*" --source weekly-51 --auth-mode login`  
```
upload existing backup:  
```
`az storage blob upload-batch --account-name s612radixvelerodevdr --destination weekly-dr-test --source ./`  
```
```
RADIX_ZONE_ENV=../../radix-zone/radix_zone_dr.env SOURCE_CLUSTER=weekly-dr-test BACKUP_NAME=all-hourly-20231219090009 ./restore_apps.sh
```

## Flux
Add radix_acr_repo_url to development, updated postbuild flag to match dr  

## Update Radix Deployments

If ACR is different than original, this must be updated
Run the go application, (run go mod download first), check the old and new repository names matches your expectations  
```
scripts/acr/update-rd-acr.go 
```  

## Web console
Change redirect url in auth secrets to https://auth-radix-web-console-qa.weekly-dr-test.dev.radix.equinor.com/oauth2/callback  
Add redirect url  
```
"https://auth-radix-web-console-qa.weekly-dr-test.dev.radix.equinor.com/oauth2/callback"
```
in 5687b237-eda3-4ec3-a2a1-023e85a2bd84 / "Omnia Radix Web Console - Development Clusters"  
Add redirect url 
```
"https://auth-radix-web-console-qa.weekly-dr-test.dev.radix.equinor.com/applications"
```
to "Single page applications" section  
