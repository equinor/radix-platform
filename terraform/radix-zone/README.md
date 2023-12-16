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

move state file to azure with sync.sh

## secrets
radix-cost-allocation-db-writer-dev
radix-cost-allocation-db-admin
radix-cicd-canary-values
radix-vulnerability-scan-db-writer-dev
radix-vulnerability-scan-db-admin
radix-vulnerability-scan-db-api-dev
radix-vulnerability-scan-db-admin
acr-whitelist-ips-dev
// flux-github-deploy-key-private
// flux-github-deploy-key-public
slack-webhook-dev