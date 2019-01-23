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

environment = "prod" | "dev"

- `fg_radix_cluster_admin_{environment}`  
  Contributor to resource group `clusters`.  
  Can then create and destroy Kubernetes clusters.
- `fg_radix_common_resource_admin_{environment}`  
  Contributor to resource group `common`.  
  Can work on any of the common managed services.
- `fg_radix_dns_admin_{environment}`  
  DNS Zone Contributor for the DNS Zone in each environment (ex: `radix.equinor.com` in prod).  
  Used by external-dns and cert-manager to manage automatic DNS updates on Azure DNS service.
- `fg_radix_monitoring_admin_{environment}`  
  Contributor to resource group `monitoring`.  
  Can do anything related to the external monitoring of clusters.

#### Deprecated groups

- `fg_radix_platform_admin`  
  Replaced by `fg_radix_cluster_admin_{environment}` when we move into multiple infrastructure environments.

### Service principals

Platform components have various need for access to resources to perform their job, and we use azure service principals (system users) to provide the components access according to use case.  

environment = "prod" | "dev"

- `radix-cr-reader-{environment}`  
   A system user that should only be able to pull images from container registry.
- `radix-cr-cicd-{environment}`  
   A system user for providing radix cicd access to container registry.
- `radix-cluster-{environment}`  
   A system user that control all clusters and related vnets in the resource group `clusters`.
- `radix-dns-{environment}`  
  A system user for providing external-dns k8s component access to Azure DNS.

Provisioning (create and update user, role assignments) is handled by script [install_infrastructure.sh](https://github.com/equinor/radix-platform/blob/master/scripts/install_infrastructure.sh).  
The credentials for each SP is stored as a secret in the `radix-vault-{environment}` key vault using the format provided by the [service-principal.template.json](https://github.com/equinor/radix-platform/blob/master/scripts/service-principal.template.json) json template.

#### Inspect role assignments
```
# List roles for SP
SP_NAME="radix-cr-reader-dev"
az role assignment list --all --assignee "http://${SP_NAME}"
```

Note the use of `--all`.  
The `list` command default to list role assignments for subscription and resource groups. `--all` lets you see assignments for, well, all resources.

#### Mitigations

Users with permissions from either

- `fg_radix_cluster_admin_*`
- `fg_radix_common_resource_admin_*`

can do substantial damage if accounts are either compromised or due to errors.

To mitigate this the permissions are only given to a user when needed and for a short time. On average these permissions should only apply to one or two team members maybe one day every month on the Production subscription.

There is a risk that we forget to remove the permissions after the necessary work has completed. The options we have to mitigate this are

- Create a small nightly job that checks that there are no members of these two groups.  
  If there are any members a notification can be sent on Slack.
- Make use of [Azure AD Privileged Identity Management](https://docs.microsoft.com/en-us/azure/active-directory/privileged-identity-management/pim-configure) (PIM).  
  See also [Azure AD Privileged Identity Management in Equinor](./pim.md) for how/when this will be available in Equinor.  


## Access control for radix platform <a name="platform"></a>

### Security groups

`fg_radix_platform_user`

Granted to developers hosting their application in radix platform. At the moment this AD group is manually maintained by the radix developing team, and can be applied for through [slack channel](https://equinor.slack.com/messages/CBKM6N2JY/convo/G9M0R6BSB-1535027466.000100/).



- Grants access to connect to hosted kubernetes resources in radix azure subscription. A new azure role has been made for this group, limiting access as much as possible. This is based on [issue](https://github.com/Azure/AKS/issues/413#issuecomment-410334065) posted to Azure/AKS team.  
- Grants access to list and watch namespaces, jobs, ingress and radixconfig for all namespaces in AKS (no sensitive information). We would like to only grant access to k8s objects related to apps they own, however there is a limitation in kubernetes when it comes to finding resources that a user has access to without allowing list/watch. This is reported by several on kubernetes git issues [1](https://github.com/kubernetes/community/issues/1486) [2](https://github.com/kubernetes/kubernetes/issues/58262) [3](https://github.com/kubernetes/kubernetes/issues/40403). When radix api is implemented, we can revoked more and more of these grants, and get a more secure solution enforced. The role is granted in [radix-boot-config](https://github.com/equinor/radix-boot-configs/pull/50) during creation of cluster
- Grants access to create new [RadixRegistrations](https://github.com/equinor/radix-operator/blob/developer/docs/radixregistration.md). In the RadixRegistration a AD group should be provided. 
- The group provided in RadixRegistration will own the application and be granted further access to resources created based on the RadixRegistration or by the [RadixConfig](https://github.com/equinor/radix-operator/blob/developer/docs/radixconfig.md) in the git repo defined in RadixRegistration. This includes get/update/delete the [RadixRegistration](https://github.com/equinor/radix-operator/blob/developer/pkg/apis/kube/roles.go) [[|]] object and get/list/watch/create/delete [RadixDeployment](https://github.com/equinor/radix-operator/blob/developer/pkg/apis/kube/roles.go), deployments, pods, logs, services in [namespaces](https://github.com/equinor/radix-operator/blob/developer/charts/radix-operator/templates/rbac.yaml) created based on RadixApplication. These roles and [rolebinding](https://github.com/equinor/radix-operator/blob/developer/pkg/apis/kube/rolebinding.go) are granted by the radix-operator


`fg_radix_platform_development`  

Grants k8s `cluster-admin` role.


