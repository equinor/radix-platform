# How to deploy the Radix platform and required infrastructure

Each environment (`prod`, `dev`) has multiple clusters that use shared infrastructure like DNS and ACR in that environment. The deployment and removal of mostly everything is done by script.

**Note** The recommended approach for creating new official clusters (be it new weekly, new playground or new prod cluster) now is to use migration from the current active cluster.

## Prerequisites

- You must have the Azure role `Owner` for the Azure subscription that is the infrastructure environment
- Be able to run `bash` scripts (linux/macOs)
- Clone this repo
- `cd scripts`
- `az login` into the correct subscription

The following applications tools/applications are required to run the platform scripts:

* [az](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [helm](https://helm.sh/docs/intro/install/)
* [jq](https://stedolan.github.io/jq/)
* htpasswd
* envsubst
* [velero](https://velero.io/docs/v1.8/basic-install/)
* [flux](https://fluxcd.io/docs/cmd/)
* [sqlcmd](https://docs.microsoft.com/en-us/sql/tools/sqlcmd-utility?view=sql-server-ver15)

## 1. Install and update shared infrastructure

**NB: You only need to do this once per Azure subscription!** Multiple clusters will share the same base infrastructure.

Handled by script, see [radix-zone/base-infrastructure/README.md](./radix-zone/base-infrastructure/README.md#bootstrap) for details.

## 2 Set up cluster

A cluster can be set up in two different ways. Either by migrating from an existing cluster to a non-existing cluster (ref 2.1) or by creating a new cluster from scratch.

### 2.1 Migrate cluster

NOTE: If there is a need to migrate to a new cluster with a different setup, please run through the bootstrap and installation of base components described below

This scripts takes care of bootstrapping new cluster (if it hasn't been created beforehand with base-components installed) install base components and migrate Radix resources to new cluster.

The whole process should be handled by the [migrate.sh](./migrate.sh) script. See file header in for usage. The only exception is the last manual step to make the cluster the active one.

### 2.2 Setting up a cluster from scratch

There are seven steps to setting up a Radix cluster from scratch. These steps can be run individually when modifying an existing cluster, or sequentially when setting up a new cluster:

1. Install infrastructure (described above)
2. Bootstrap
3. Deploy base components
4. Deploy Radix applications
5. Create GitHub webhooks
6. Create aliases (`prod` only)
7. Install network security test

#### Step 2 Bootstrap and teardown of a Radix cluster

- [./aks/bootstrap](./aks/README.md#bootstrap)
- [./aks/teardown](./aks/README.md#teardown)

#### Step 3 Deploy base components

This will deploy third party components (`nginx`, `external-dns` etc).

Handled by script, see file header in [install_base_components.sh](./install_base_components.sh) for usage.

##### Dependencies

###### Secrets

This script requires secret files to be available in the `keyvault` of the corresponding subscription (i.e. `radixprod` or `radixdev`), as follows.

* `slack-token`
* `prometheus-token` # htpasswd file used to authenticate towards Prometheus
* `grafana-database-password` # grafana database password
* `external-dns-azure-secret` # external-dns credentials file

**NB: The `keyvault` is created by the "install infrastructure" step**

###### Images

The base components include `radix-operator`, and for this component to be successfully deployed, the following images need to be built and pushed to the ACR.

* `radix-operator` (from `master` and `release` branches in `radix-operator` project)
* `radix-pipeline` (from `master` and `release` branches in `radix-operator` project)
* `radix-image-builder` (from `master` and `release` branches in `radix-operator` project)

#### Step 4 Deploy Radix applications

This will deploy Radix applications like radix-api, webhook, web-console etc.  

Scripted, see file header in [deploy_radix_apps.sh](./deploy_radix_apps.sh) for usage.

##### Dependencies

###### Secrets

This script requires several secret files that contain `RadixRegistration` object configurations to be available in the `keyvault` of the corresponding subscription (ex: `radix-vault-dev`), as follows.

* `radix-api-radixregistration-values`
* `radix-cost-allocation-api-radixregistration-values`
* `radix-canary-radixregistration-values`
* `radix-github-webhook-radixregistration-values`
* `radix-public-site-values`
* `radix-web-console-radixregistration-values`
* `radix-vulnerability-scanner-api-radixregistration-values`
* `radix-servicenow-proxy-radixregistration-values`

#### Step 5 Create Github webhooks for Radix apps

This will create webhooks that will connect Radix application github repos with the radix CI/CD.

Handled by script, see file header in [create_web_hooks_radix_apps.sh](./create_web_hooks_radix_apps.sh) for usage.

##### Dependencies

The radix component `radix-github-webhook-prod` must be available in the cluster.

#### Step 6 Create/update aliases

**NB: Aliases should only be set for apps running in the `prod` cluster**

It is a way to provide a more user friendly url to a selected set of apps (i.e. Web Console, Public Site, API server, Webhook, Canary).  

Handled by script, see [app_alias/README](./app_alias/README.md)

