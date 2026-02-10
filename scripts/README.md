# How to deploy the Radix platform and required infrastructure

Each environment (`prod`, `dev`) has multiple clusters that use shared infrastructure like DNS and ACR in that environment. The deployment and removal of mostly everything is done by script.

**Note** The recommended approach for creating new official clusters (be it new weekly, new playground or new prod cluster) now is to use migration from the current active cluster.

## Prerequisites

- ~~You must have the Azure role `Owner` for the Azure subscription that is the infrastructure environment~~
- You must have the Azure role `Contributer` for the Azure subscription that is the infrastructure environment
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
* [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli#install-cli)

## 1. Install and update shared infrastructure

**NB: You only need to do this once per Azure subscription!** Multiple clusters will share the same base infrastructure.

Handled by terraform, see [terraform/subscriptions/README.md](./terraform/subscriptions/README.md#bootstrap) for details.

## 2 Set up cluster

A cluster can be set up in two different ways. Either by migrating from an existing cluster to a non-existing cluster (ref 2.1) or by creating a new cluster from scratch.

### 2.1 Migrate cluster

NOTE: If there is a need to migrate to a new cluster with a different setup, please run through the bootstrap and installation of base components described below

This scripts takes care of bootstrapping new cluster (if it hasn't been created beforehand with base-components installed) install base components and migrate Radix resources to new cluster.

- PIM yourself to `AZ PIM OMNIA RADIX Cluster Admin - <dev or prod>` group, and `Radix Confidential Data Contributor` and `Contributor` resource for the respective subscription
- Teardown old cluster
    - Modify `/terraform/subscriptions/<s940|s941>/<zone>/config.yaml` and comment out the cluster to be removed
    - Run `teardown.sh` in `scripts/aks/teardown.sh`
- Migrate new cluster:
    - Add new cluster to `/terraform/subscriptions/<s940|s941>/<zone>/config.yaml` but do not set `activecluster` to true yet
    - Run script by the [migrate.sh](./migrate.sh). See file header in for usage
    - Follow the procedure from the script.
    - After cluster is created from the Github Action, verify the cluster in Azure
    - After Github Action is finished, press space to space to continue in the migration script

#### 2.1.1 Set new cluster to active

The following steps should only be performed when `active-to-active` was selected as migration strategy in `migrate.sh`.

Steps:
1. Run [move_custom_ingresses.sh](./move_custom_ingresses.sh).
2. In [radix-flux](https://github.com/equinor/radix-flux): Set `ACTIVE_CLUSTER` to the new cluster name in `postBuild.yaml` for the respective Radix zone.

### 2.2 Setting up a cluster from scratch

There are seven steps to setting up a Radix cluster from scratch. These steps can be run individually when modifying an existing cluster, or sequentially when setting up a new cluster:

- PIM yourself to 'AZ PIM OMNIA RADIX Cluster Admin - `<dev or prod>`' and `Radix Confidential Data Contributor` for the respective subscription
- Modify the ./terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/config.yaml to reflect the new cluster
- Create a pull request to master"
- Monitor the github action and the result
- After approval, run the GitHub Action 'AKS Apply', and tick of the 'Terraform Apply' checkbox
- Navigate to ./terraform/subscriptions/$AZ_SUBSCRIPTION_NAME/$RADIX_ZONE/post-clusters
- Execute ```terraform apply```
- Deploy base components
- Install Radix components
- Deploy Radix applications
- Create aliases (`prod` only)
- Install network security test

#### Step 2 Bootstrap and teardown of a Radix cluster

- [./aks/bootstrap](./aks/README.md#bootstrap)
- [./aks/teardown](./aks/teardown.sh)

#### Step 3 Deploy base components

This will deploy 3rd party components (`nginx`, `cert-manager`, `flux` etc).

Handled by script, see header in [install_base_components.sh](./install_base_components.sh) for usage.

##### Dependencies

###### Secrets

This script requires secret files to be available in the `keyvault` of the corresponding cluster as follows.

* `slack-token`

**NB: The `keyvault` is created by the "install infrastructure" step**

#### Step 4 Install Radix components

The Radix components will be automatically installed by Flux.

###### Dependencies - Images

The base components include `radix-operator`, and for this component to be successfully deployed, the following images need to be built and pushed to the ACR.

* `radix-operator` (from `master` and `release` branches in `radix-operator` project)
* `radix-pipeline` (from `master` and `release` branches in `radix-operator` project)
* `radix-image-builder` (from `master` and `release` branches in `radix-operator` project)


#### Step 5 Deploy Radix applications

This step will register and deploy Radix applications. Radix application registration are restored from backup (Velero) or manually registered.

(For now deploy keys and webhooks are refreshed manually once every year) (for now!)

##### Dependencies

The radix component `radix-github-webhook-prod` must be available in the cluster.
