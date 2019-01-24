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

Each environment has it's own subscription.  
The environments have an similar structure (resource groups, resources etc) and security groups.  
Each resource and security group use a naming convention that include the environment name.

![Infrastructure overview](./diagrams/infrastructure-overview.png)


## Subscriptions

- "Omnia Radix Production"
- "Omnia Radix Development"

## Resource groups

- `clusters`   
- `common`  
- `monitoring`

The usage patterns for each resource group is typically different and that is why they are separated:

- Work is done in `clusters` resource group every ~3 months in environment `prod` when setting up and migrating to a new cluster
- Work is done in `common` resource group whenever there are changes or new features to managed services we rely on
- Work is done in `monitoring` typically more often than in `common` and there is less sensitive data and services there so permissions to this can be given  

See also [access-control](./access-control.md).


## Azure DNS

There is a Azure DNS service in both Production and Development subscriptions.  
Equinor have delegated radix.equinor.com to Azure DNS zone radix.equinor.com in resource group radix-common-prod in Omnia Radix Production subscription.  
From there, we have delegated dev.radix.equinor.com to Azure DNS with same name in resource group radix-common-dev in Omnia Radix Development subscription.     

## DNS CAA

Info about CAA: https://letsencrypt.org/docs/caa/

Equinor.com is protected by a Certificate Authority Authorization record set to Digicert, which means other CAs (such as Let's Encrypt) will REFUSE to issue certificates to any sub-domainnames (unless overriden).

After instruction from LKSK we will allow godaddy,letsencrypt and digicert to issue certificates for radix.equinor.com. We allow that by setting some CAA records on radix.equinor.com which we control and is hosted on Azure DNS.

> PS: CAA records cannot be set, or viewed, in the Azure Portal. They are only available using AZ CLI.

We use https://sslmate.com/caa/ to give us the correct format for our records. We then create them using AZ CLI:
```
    az network dns record-set caa add-record -g radix-common-prod --zone-name radix.equinor.com --record-set-name @ --flags 0 --tag "issue" --value "letsencrypt.org"
    az network dns record-set caa add-record -g radix-common-prod --zone-name radix.equinor.com --record-set-name @ --flags 0 --tag "issue" --value "digicert.com"
    az network dns record-set caa add-record -g radix-common-prod --zone-name radix.equinor.com --record-set-name @ --flags 0 --tag "issue" --value "godaddy.com"
```
We also verify that they have been created:
```
    az network dns record-set caa list -g radix-common-prod --zone-name radix.equinor.com --output table
```

Output:
```
    Name    ResourceGroup        Ttl  Type    Metadata
    ------  -----------------  -----  ------  ----------
    @       radix-common-prod   3600  CAA
```
And finally use an external service to verify that the changes are visible in DNS globally: https://caatest.co.uk/radix.equinor.com

Now we can use Let's Encrypt to issue certificates to what.ever.radix.equinor.com :-)

See also [cert-management](cert-management.md) for how this is configured in a radix cluster.


## Initial scaffolding <a name="scaffolding"></a>

The very first time Omnia Radix is set up there are some steps that are first done by a user with `Owner` permissions on subscription level:

1. Create resource groups according to default structcure in each subscription
1. Provision shared infrastructure components (dns, container registry etc)
1. Configure access to resources by adding security group and role to each resource group (see overview for details)

This provisioning is all handled by script, see [install_infrastructure.sh](https://github.com/equinor/radix-platform/blob/master/scripts/install_infrastructure.sh).  






