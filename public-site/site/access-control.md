---
title: Azure access control
layout: document
toc: true
---

## Overview

The purpose of access control in Azure is

- [_For Radix users_](#platform):
  - To limit access to the teams own applications and resources only
- [_For platform developers_](#infrastructure):
  - To limit the risk of accidental disruptive changes
  - To limit the risk if accounts are compromised

As far as possible we want to use [Azure built-in roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles).  

The configuration of security group and system user permissions is handled by script when also configuring the shared infrastructure, see [azure resources - initial scaffolding](./azure-resources.md#scaffolding).

## Access control for infrastructure <a name="infrastructure"></a>

### Security groups 

We create these groups to govern access to the resource groups, and if necessary, sub-resources:

[environment] = "prod" | "dev"

- `fg_radix_platform_cluster_admin_[environment]`  
  Contributor of clusters resource group. Can then create and destroy Kubernetes clusters
- `fg_radix_platform_common_resource_admin_[environment]`  
  Contributor of radix-common-dev|prod resource group. Can work on any of the common managed services
- `fg_radix_platform_dns_[environment]`  
  DNS Zone Contributor of `radix-common-*`. Used by external-dns and cert-manager to manage automatic DNS updates on Azure DNS service.
- `fg_radix_platform_monitoring_[environment]`  
  Contributor of radix-monitoring resource group. Can do anything related to the external monitoring of clusters

#### Mitigations

Users with permissions from either

- `radix_platform_cluster_admin`
- `radix_platform_common_resource_admin`

can do substantial damage if accounts are either compromised or due to errors.

To mitigate this the permissions are only given to a user when needed and for a short time. On average these permissions should only apply to one or two team members maybe one day every month on the Production subscription.

There is a risk that we forget to remove the permissions after the necessary work has completed. The options we have to mitigate this are

- Create a small nightly job that checks that there are no members of these two groups.  
  If there are any members a notification can be sent on Slack.
- Make use of [Azure AD Privileged Identity Management](https://docs.microsoft.com/en-us/azure/active-directory/privileged-identity-management/pim-configure) (PIM)

#### Azure AD Privileged Identity Management in Equinor

IAM want to use PIM for all azure subcriptions and related roles, and the intial scaffolding from their side is up and running.

The configuration per app looks like this
1. Azure roles are related to azure ad groups (configured in PIM)
1. Group membership is managed in AccessIT
1. Group member ask PIM to be granted the role on a time based limit in the azure portal

![Azure PIM Equinor](./images/azpim-equinor.jpg)

#### TODO - update docs when transition to new security model is done

_Current groups_:  
fg_radix_platform_admin  
fg_radix_platform_development  
fg_radix_platform_dns  
fg_radix_platform_user  

_Next version PROD groups (infrastructure)_:  

- fg_radix_cluster_admin_prod  
- fg_radix_common_resource_admin_prod  
- fg_radix_dns_admin_prod  
- fg_radix_monitoring_admin_prod  

_Next version DEV groups_ (infrastructure):  

- fg_radix_cluster_admin_dev  
- fg_radix_common_resource_admin_dev  
- fg_radix_dns_admin_dev  
- fg_radix_monitoring_admin_dev  


## Access control for radix platform <a name="platform"></a>

### Security groups

`fg_radix_platform_user`

Granted to developers hosting their application in radix platform. At the moment this AD group is manually maintained by the radix developing team, and can be applied for through [slack channel](https://equinor.slack.com/messages/CBKM6N2JY/convo/G9M0R6BSB-1535027466.000100/).



- Grants access to connect to hosted kubernetes resources in radix azure subscription. A new azure role has been made for this group, limiting access as much as possible. This is based on [issue](https://github.com/Azure/AKS/issues/413#issuecomment-410334065) posted to Azure/AKS team.  
- Grants access to list and watch namespaces, jobs, ingress and radixconfig for all namespaces in AKS (no sensitive information). We would like to only grant access to k8s objects related to apps they own, however there is a limitation in kubernetes when it comes to finding resources that a user has access to without allowing list/watch. This is reported by several on kubernetes git issues [1](https://github.com/kubernetes/community/issues/1486) [2](https://github.com/kubernetes/kubernetes/issues/58262) [3](https://github.com/kubernetes/kubernetes/issues/40403). When radix api is implemented, we can revoked more and more of these grants, and get a more secure solution enforced. The role is granted in [radix-boot-config](https://github.com/equinor/radix-boot-configs/pull/50) during creation of cluster
- Grants access to create new [RadixRegistrations](https://github.com/equinor/radix-operator/blob/developer/docs/radixregistration.md). In the RadixRegistration a AD group should be provided. 
- The group provided in RadixRegistration will own the application and be granted further access to resources created based on the RadixRegistration or by the [RadixConfig](https://github.com/equinor/radix-operator/blob/developer/docs/radixconfig.md) in the git repo defined in RadixRegistration. This includes get/update/delete the [RadixRegistration](https://github.com/equinor/radix-operator/blob/developer/pkg/apis/kube/roles.go) [[|]] object and get/list/watch/create/delete [RadixDeployment](https://github.com/equinor/radix-operator/blob/developer/pkg/apis/kube/roles.go), deployments, pods, logs, services in [namespaces](https://github.com/equinor/radix-operator/blob/developer/charts/radix-operator/templates/rbac.yaml) created based on RadixApplication. These roles and [rolebinding](https://github.com/equinor/radix-operator/blob/developer/pkg/apis/kube/rolebinding.go) are granted by the radix-operator


### Azure Service Principal

System accounts which can be rbac'ed.  
_Password is only exposed once_, when you create the sp (service principal).

For details on creating then run
```
az ad sp create --help
```

Running `sp create` multiple times will update an existing sp's metadata and role assignments (when role assignments are part of the create func arguments).

For details on resetting credentials then run
```
az ad sp reset-credentials --help
```

### Role assignments

```
az role assignment list --all --assignee xxxxxx
```

Note the use of `--all`. The `list` command default to list role assignments for subscription and resource groups. `--all` lets you see assignments for, well, all resources.
