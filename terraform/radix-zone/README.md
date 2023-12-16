# DR:
# Comment out backend "azurerm" {} to run local
terraform/infrastructure/s941/dev/resourcegroups/main.tf # local
scripts/radix-zone/base-infrastructure/bootstrap.sh
terraform/oidc/rbac/main.tf # local
terraform/infrastructure/s941/dev/keyvaults/main.tf # local
terraform/infrastructure/s941/dev/storageaccounts/main.tf # local

USE BACKEND
change values in .env files:
resource_group_name="s612-tfstate"
storage_account_name ="s612radixinfra"
client_id="github maintenance clientid"
client_secret="github maintenance secret"
subscription_id="DR subscription"

terraform/infrastructure/s941/dev/networkmanager/main.tf
scripts/service-principals-and-aad-apps/refresh_web_console_app_credentials.sh
scripts/velero/bootstrap.sh

scripts/radix-zone/monitoring-infrastructure/bootstrap.sh
terraform/infrastructure/s941/dev/sqldatabases/main.tf

move state file to azure with sync.sh

scripts/aks/bootstrap.sh

generate secrets for:
radix-cost-allocation-db-admin 
    password=$(openssl rand -base64 32 | tr -- '+/' '-_')
    az keyvault secret set --vault-name "radix-vault-dev-dr2" --name "radix-cost-allocation-db-admin" --value "${password}"
radix-vulnerability-scan-db-admin 
    password=$(openssl rand -base64 32 | tr -- '+/' '-_')
    az keyvault secret set --vault-name "radix-vault-dev-dr2" --name "radix-vulnerability-scan-db-admin" --value "${password}"
mysql-grafana-dev-admin-password
    password=$(openssl rand -base64 32 | tr -- '+/' '-_')
    az keyvault secret set --vault-name "radix-monitoring-dev-dr" --name "mysql-grafana-dev-admin-password" --value "${password}"
s612-radix-grafana-dev-mysql-admin-pwd
    password=$(openssl rand -base64 32 | tr -- '+/' '-_')
    az keyvault secret set --vault-name "radix-monitoring-dev-dr" --name "s612-radix-grafana-dev-mysql-admin-pwd" --value "${password}"

terraform/infrastructure/s941/dev/mysql/main.tf
scripts/vulnerability-scanner/bootstrap.sh REGENERATE_SCANNER_PASSWORD=true REGENERATE_API_PASSWORD=true
    radix-vulnerability-scan-db-writer-dev
    radix-vulnerability-scan-db-api-dev
scripts/cost-allocation/bootstrap.sh REGENERATE_API_PASSWORD=true REGENERATE_COLLECTOR_PASSWORD=true
    radix-cost-allocation-db-api-dev
    radix-cost-allocation-db-writer-dev


## secrets
acr-whitelist-ips-dev
// flux-github-deploy-key-private
// flux-github-deploy-key-public
slack-webhook-dev

# TODO find a way to genereate secret
radix-cicd-canary-values