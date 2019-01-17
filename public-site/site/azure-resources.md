---
title: Azure resources
layout: document
toc: true
---

## Overview

In Azure we use a two layer cake for resource control:

1. The top layer is _subscription_
1. The second layer is _resource group(s)_

A _subscription_ give you the power to control resource groups.  
A _resource group_ give you the power to control resources.

(In Azure there is a level above subscription called _management groups_, but we are not into that scene. Yet.)  

We have defined two environments:  
- `prod`  
  Used for production workloads including customer developers test environments.  
- `dev`  
  Used for developing the Radix platform itself.

Each environment has a subscription.  
Each subscription use a specific set of resource groups according to usage pattern.   
Each resource use a naming convention that include the environment name.    

### Default structure

[environment] = "prod" | "dev"

- `Omnia Radix [environment]`  
  A subcriptions that is one of: `Omnia Radix Prod`, `Omina Radix Dev`
  - `clusters`  
    Purpose: Resource group for all clusters (AKS)  
    Security group: `fg_radix_cluster_admin_[environment]`  
    Role: `contributor`       
    - `Azure Kubernetes Service (AKS)`  
      Purpose: k8s cluster for running the radix platform  
      Naming convention: Any string that pass az resource naming validation  
      Domain name convention: `[cluster-name].[environment].radix.equinor.com`  
    - etc ...
  - `common`  
    Purpose: Resource group for shared resources.  
    Security group: `fg_radix_common_resource_admin_[environment]`  
    Role: `contributor`          
    - `DNS Zone`  
      Naming convention: `[environment].radix.equinor.com`        
    - `Keyvault`  
      Naming convention: `radix-vault-[environment]`
    - `Container registry`  
      Naming convention: `radix-registry-[environment]`  
      Domain name convention: `radix-registry-[environment].azurecr.io`
    - etc ...
  - `monitoring` (1)    
    Purpose: Resource group for monitoring tools 
    - `Monitoring app`  
      Purpose: Monitoring across all clusters.  
      Naming convention: `radix-grafana-[environment]`  
      Security group (AD): `fg_radix_monitoring_admin_[environment]`  
      Role: `contributor`

(1) A `prod` only resource group.

### Usage patterns

The usage patterns for each resource group is typically different and that is why they are separated:

- Work is done in `clusters` resource group every ~3 months in environment `prod` when setting up and migrating to a new cluster
- Work is done in `common` resource group whenever there are changes or new features to managed services we rely on
- Work is done in `monitoring` typically more often than in `common` and there is less sensitive data and services there so permissions to this can be given        

## Initial scaffolding <a name="scaffolding"></a>

The very first time Omnia Radix is set up there are some steps that are first done by a user with `Owner` permissions on subscription level:

1. Create resource groups according to default structcure in each subscription
1. Provision shared infrastructure components (dns, container registry etc)
1. Configure access to resources by adding security group and role to each resource group (see overview for details)

This provisioning is all handled by script, see `/scripts/install_infrastructure.sh`.  

## Parts

### Container registry

Use cases:
- Deploy containers (pull)
- CICD (pull and push)

Service Principal per use case
- name: "radix-registry-reader"
  roles: pull
- name: "radix-registry-cicd"
  roles: pull, push

## How to Azure all the things

### Subscriptions

Selecting the correct subscription in the Azure Portal is done when creating a resource group. In Azure CLI it's done by 

```sh
az account list --output table
az account set --subscription "Omnia Radix Development"
```

> **PS**: You have to re run "az login" after being added to a new subscription for it to show up in az account.

### Clusters

List clusters in a subscription:

    az aks list --output table

Get credentials for a cluster (to make kubectl work):

    az aks get-credentials --admin --resource-group RG_NAME --name CLUSTER_NAME

Scaling a cluster:

Horizontal scaling seems to work ok in a live environment.

    az aks scale --name CLUSTER_NAME --resource-group RG_NAME --node-count 3

Vertical scaling has not yet been tested.

    az vmss update --resource-group RG_NAME n {name} --set sku.name="YOUR_VALUE"
    # If you are changing from Standard to Premium you must also include --set sku.tier="Premium"


### Managed services

Managed services are typically services that we do not build/rebuild and deploy/redeploy ourselves so have a lesser need of being automated.

#### Azure DNS

There is a Azure DNS service in both Production and Development subscriptions.

Equinor have delegated radix.equinor.com to Azure DNS zone radix.equinor.com in resource group radix-common-prod in Omnia Radix Production subscription.

From there, we have delegated dev.radix.equinor.com to Azure DNS with same name in resource group radix-common-dev in Omnia Radix Development subscription.

#### DNS CAA

Info about CAA: https://letsencrypt.org/docs/caa/

Equinor.com is protected by a Certificate Authority Authorization record set to Digicert, which means other CAs (such as Let's Encrypt) will REFUSE to issue certificates to any sub-domainnames (unless overriden).

After instruction from LKSK we will allow godaddy,letsencrypt and digicert to issue certificates for radix.equinor.com. We allow that by setting some CAA records on radix.equinor.com which we control and is hosted on Azure DNS.

> PS: CAA records cannot be set, or viewed, in the Azure Portal. They are only available using AZ CLI.

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

#### Azure Container Registry

> Information about Azure ACR SKUs: https://docs.microsoft.com/en-us/azure/container-registry/container-registry-skus

##### Setup

###### Prod

    az account set --subscription "Omnia Radix Production"
    az group show --name radix-common-prod
    az group create --location northeurope --name radix-common-prod
    az acr create --name radix --resource-group radix-common-prod --sku Standard

###### Dev

    az account set --subscription "Omnia Radix Development"
    az group show --name radix-common-dev
    az group create --location northeurope --name radix-common-dev
    az acr create --name radixdev --resource-group radix-common-dev --sku Standard
       

##### Usage

Log in to the ACR (so that docker push/pull commands work locally) by doing:

###### Prod

    az account set --subscription "Omnia Radix Production"
    az acr login --name radix

###### Dev

    az account set --subscription "Omnia Radix Development"
    az acr login --name radixdev



#### Azure Key Vault

Azure Key Vault can be thought about as a code repository for secrets.

## Setup

###### Prod

    az keyvault list --resource-group radix-common-prod

    az keyvault create --name radix-vault \
                    --resource-group radix-common-prod \
                    --location northeurope

###### Dev

    az keyvault list --resource-group radix-common-dev

    az keyvault create --name radix-vault-dev \
                    --resource-group radix-common-dev \
                    --location northeurope

##### Usage

Upload text:

    az keyvault secret set --name radix-grafana-aad-client-secret \
                        --vault-name radix-vault-dev \
                        --description "Secret used between Grafana backend and Azure AD for authentication" \
                        --value "xx"

Upload file:

    az keyvault secret set --name radix-grafana-aad-client-secret \
                        --vault-name radix-vault-dev \
                        --description "Secret used between Grafana backend and Azure AD for authentication" \
                        --file mysecrets.txt

Get secrets:

    az keyvault secret list --vault-name radix-vault-dev

Get one secret:

    az keyvault secret show --name radix-grafana-aad-client-secret \
                        --vault-name radix-vault-dev \
                        --output table
