---
title: Azure access control
layout: document
toc: true
---

The purpose of access control in Azure is

- _For Radix users_:
  - To limit access to the teams own applications and resources only
- _For platform developers_:
  - To limit the risk of accidental disruptive changes
  - To limit the risk if accounts are compromised

As far as possible we want to use Azure built-in roles.

## Initial scaffolding

The very first time Omnia Radix is set up there are some steps that are first done by a user with `Owner` permissions on subscription level:

- Create resource group `clusters` in each subscription
- Create resource group `radix-common-dev|prod` in each subscription
- Create resource group `radix-monitoring` in `Production` subscription

### Usage patterns

The usage patterns for each resource group is typically different and that is why they are separated:

- Work is done in `clusters` resource group every ~3 months on Production when setting up and migrating to a new cluster
- Work is done in `radix-common-*` resource group whenever there are changes or new features to managed services we rely on
- Work is done in `radix-monitoring` typically more often than in `radix-common-*` and there is less sensitive data and services there so permissions to this can be given more freely

## Access control

### Security groups  

We create these groups to govern access to the resource groups, and if necessary, sub-resources:

- `radix_platform_cluster_admin`  
  Contributor of clusters resource group. Can then create and destroy Kubernetes clusters
- `radix_platform_common_resource_admin`  
  Contributor of radix-common-dev|prod resource group. Can work on any of the common managed services
- `radix_platform_monitoring`  
  Contributor of radix-monitoring resource group. Can do anything related to the external monitoring of clusters
- `fg_radix_platform_dns`  
  DNS Zone Contributor of `radix-common-*`. Used by external-dns and cert-manager to manage automatic DNS updates on Azure DNS service.

Users with `radix_platform_cluster_admin` or `radix_platform_common_resource_admin` permissions can do substantial damage if accounts are either compromised or due to errors.

To mitigate this the permissions are only given to a user when needed and for a short time. On average these permissions should only apply to one or two team members maybe one day every month on the Production subscription.

There is a risk that we forget to remove the permissions after the necessary work has completed. The options we have to mitigate this are

- Create a small nightly job that checks that there are no members of these two groups. If there are any members a notification can be sent on Slack.
- Make use of [Azure AD Privileged Identity Management](https://docs.microsoft.com/en-us/azure/active-directory/privileged-identity-management/pim-configure) (PIM)

### Azure AD Privileged Identity Management in Equinor

IAM want to use PIM for all azure subcriptions and related roles, and the intial scaffolding from their side is up and running.

The configuration per app looks like this
1. Azure roles are related to azure ad groups (configured in PIM)
1. Group membership is managed in AccessIT
1. Group member ask PIM to be granted the role on a time based limit in the azure portal

![Azure PIM Equinor](./images/azpim-equinor.jpg)