## Subscriptions

Omnia Radix Production - Used for production workloads including customer developers test environments.

Omnia Radix Development - Used for developing the Radix platform itself.

Selecting the correct subscription in the Azure Portal is done when creating a resource group. In Azure CLI it's done by 
    az account list --output table
    az account set --subscription "Omnia Radix Development"

PS: You have to re run "az login" after being added to a new subscription for it to show up in az account.

| Subscription  | Resource group     | AD Group               | Roles                 | Resource                          | Description  |
|---------------|--------------------|------------------------|-----------------------|-----------------------------------|--------------|
| Prod          |                    |                        |                       |                                   |              |
|               | radix-common-prod  | fg_radix_platform_dns  | DNS Zone Contributor  |                                   |              |
|               |                    |                        |                       | Azure DNS: radix.equinor.com      |              |
|               |                    |                        |                       |                                   |              |
| Dev           |                    |                        |                       |                                   |              |
|               | radix-common-dev   | fg_radix_platform_dns  | DNS Zone Contributor  |                                   |              |
|               |                    |                        |                       | Azure DNS: dev.radix.equinor.com  |              |
|               |                    |                        |                       | ACR: radixdev.azurecr.io          |              |


## Clusters

List clusters in a subscription:

    az aks list --output table

Get credentials for a cluster (to make kubectl work):

    az aks get-credentials --admin --resource-group RG_NAME --name CLUSTER_NAME

Scaling a cluster:

Horizontal scaling seems to work ok in a live environment.

    az aks scale --name CLUSTER_NAME --resource-group RG_NAME --node-count 3

Vertical scaling has not yet been tested.

    az vmss update -g {rg} n {name} --set sku.name="YOUR_VALUE"
    # If you are changing from Standard to Premium you must also include --set sku.tier="Premium"

## Access control

For the time being access control is done with 4 security groups:

**fg_radix_platform_admin**

**fg_radix_platform_dns**

**fg_radix_platform_development** 

* Granted to developers managing the radix platform
  * grants owner on radix azure subscription
  * admin rights on kubernetes clusters hosted under this subscription.

**fg_radix_platform_user**

Granted to developers hosting their application in radix platform. At the moment this AD group is manually maintained by the radix developing team, and can be applied for through [slack channel](https://equinor.slack.com/messages/CBKM6N2JY/convo/G9M0R6BSB-1535027466.000100/).

  * Grants access to connect to hosted kubernetes resources in radix azure subscription. A new azure role has been made for this group, limiting access as much as possible. This is based on [issue](https://github.com/Azure/AKS/issues/413#issuecomment-410334065) posted to Azure/AKS team.
  * Grants access to list and watch namespaces, jobs, ingress, radixregistrations and radixconfig for all namespaces in AKS. This is **not a secure solution**, but required for the radix web console and brigadeterm to work. The reason is that there is a limitation in kubernetes when it comes to finding resources that a user has access to without allowing list/watch, as reported by several on kubernetes git issues [1](https://github.com/kubernetes/community/issues/1486) [2](https://github.com/kubernetes/kubernetes/issues/58262) [3](https://github.com/kubernetes/kubernetes/issues/40403). When radix api is implemented, most of these access will be revoked, and a more secure solution enforced. The role is granted in [radix-boot-config](https://github.com/Statoil/radix-boot-configs/pull/50) during creation of cluster
  * Grants access to create new [RadixRegistrations](https://github.com/Statoil/radix-operator/blob/developer/docs/radixregistration.md). In the RadixRegistration a AD group should be provided. 
  * The group provided in RadixRegistration will be granted further access to resources created based on the RadixRegistration or by the [RadixConfig](https://github.com/Statoil/radix-operator/blob/developer/docs/radixconfig.md) in the git repo defined in RadixRegistration. This includes get/update/delete the [RadixRegistration](https://github.com/Statoil/radix-operator/blob/developer/pkg/apis/kube/roles.go) [[|]] object and get/list/watch/create/delete [RadixDeployment](https://github.com/Statoil/radix-operator/blob/developer/pkg/apis/kube/roles.go), deployments, pods, logs, services in [namespaces](https://github.com/Statoil/radix-operator/blob/developer/charts/radix-operator/templates/rbac.yaml) created based on RadixApplication. These roles and [rolebinding](https://github.com/Statoil/radix-operator/blob/developer/pkg/apis/kube/rolebinding.go) are granted by the radix-operator
  
### How to manage FG groups
https://equinor.service-now.com/selfservice?id=kb_article&sys_id=14a8171c6f289d00b2cbd6426e3ee4dd


## Managed services

Managed services are typically services that we do not build/rebuild and deploy/redeploy ourselves so have a lesser need of being automated.

### Azure DNS

There is a Azure DNS service in both Production and Development subscriptions.

Equinor have delegated radix.equinor.com to Azure DNS zone radix.equinor.com in resource group radix-common-prod in Omnia Radix Production subscription.

From there, we have delegatet dev.radix.equinor.com to Azure DNS with same name in resource group radix-common-dev in Omnia Radix Development subscription.

#### DNS CAA

Info about CAA: https://letsencrypt.org/docs/caa/

Equinor.com is protected by a Certificate Authority Authorization record set to Digicert, which means other CAs (such as Let's Encrypt) will REFUSE to issue certificates to any sub-domainnames (unless overriden).

After instruction from LKSK we will allow godaddy,letsencrypt and digicert to issue certificates for radix.equinor.com. We allow that by setting some CAA records on radix.equinor.com which we control and is hosted on Azure DNS.

PS: CAA records cannot be set, or viewed, in the Azure Portal. They are only available using AZ CLI.

We use https://sslmate.com/caa/ to give us the correct format for our records. We then create them using AZ CLI:

    az network dns record-set caa add-record -g radix-common-prod --zone-name radix.equinor.com --record-set-name @ --flags 0 --tag "issue" --value "letsencrypt.org"
    az network dns record-set caa add-record -g radix-common-prod --zone-name radix.equinor.com --record-set-name @ --flags 0 --tag "issue" --value "digicert.com"
    az network dns record-set caa add-record -g radix-common-prod --zone-name radix.equinor.com --record-set-name @ --flags 0 --tag "issue" --value "godaddy.com"

We also verify that they have been created:

    az network dns record-set caa list -g radix-common-prod --zone-name radix.equinor.com --output table

Output:

    Name    ResourceGroup        Ttl  Type    Metadata
    ------  -----------------  -----  ------  ----------
    @       radix-common-prod   3600  CAA

And finally use an external service to verify that the changes are visible in DNS globally: https://caatest.co.uk/radix.equinor.com

Now we can use Let's Encrypt to issue certificates to what.ever.radix.equinor.com :-)

## Azure Container Registry

On the development subscription there is a ACR registry in the radix-common-dev resource group.

Log in to the ACR (so that docker push/pull commands work locally) by doing:

    az account set --subscription "Omnia Radix Development"
    az acr login --name radixdev


## Azure Key Vault

Azure Key Vault can be thought about as a code repository for secrets.

    az keyvault list --resource-group radix-common-dev

    az keyvault create --name radix-vault-dev \
                    --resource-group radix-common-dev \
                    --location northeurope

Text:

    az keyvault secret set --name radix-grafana-aad-client-secret \
                        --vault-name radix-vault-dev \
                        --description "Secret used between Grafana backend and Azure AD for authentication" \
                        --value "xx"

File:

    az keyvault secret set --name radix-grafana-aad-client-secret \
                        --vault-name radix-vault-dev \
                        --description "Secret used between Grafana backend and Azure AD for authentication" \
                        --file mysecrets.txt

    az keyvault secret list --vault-name radix-vault-dev

    az keyvault secret show --name radix-grafana-aad-client-secret \
                        --vault-name radix-vault-dev \
                        --output table
