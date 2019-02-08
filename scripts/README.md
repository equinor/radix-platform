# Radix Infrastructure Provisioning

This `script` directory is created specifically for provisioning the Radix infrastructure on Azure.

## Create infrastructure

1. First run script `install_infrastructure.sh` to provision all dependencies that a cluster needs (e.g. keyvault, dns).  
   Please read the comments in the script file for more details on how to run it.
1. Then run script `enable_aksauditlog.sh` to enable [AKS Audit Log](https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/aks/view-master-logs.md) (an az subscription feature).

## Create cluster

`install_cluster.sh` script is used for creating a new cluster. Please read the comments in the script file for more details on how to run it. A simple example to run the script is as follows.

```
INFRASTRUCTURE_ENVIRONMENT="prod" CLUSTER_NAME="beta-3" ./install_cluster.sh
```

## Install base components

`install_base_components.sh` script is used for installing Radix base components (e.g. operator, externalDns). Please read the comments in the script file for more details on how to run it. A simple example to run the script is as follows.

```
SUBSCRIPTION_ENVIRONMENT="prod" CLUSTER_NAME="beta-3" ./install_base_components.sh
```

This script requires two secret files to be available in the `keyvault` of the corresponding subscription (i.e. `radixprod` or `radixdev`), as follows.

* `slack-token`
* `radix-stage1-values-prod` or `radix-stage1-values-dev`

The base components include `radix-operator`, and for this component to be successfully deployed, the following images need to be built and pushed to the ACR.

* `radix-operator` (from `master` and `release` branches in `radix-operator` project)
* `radix-pipeline` (from `master` and `release` branches in `radix-operator` project)
* `radix-image-builder` (from `master` and `release` branches in `radix-operator` project)
* `gitclone` (from `master` branch in `radix-api` project)

## Deploy Radix applications

`deploy_radix_apps.sh` script is used for installing Radix applications (e.g. API server, Webhook). Please read the comments in the script file for more details on how to run it. A simple example to run the script is as follows.

```
SUBSCRIPTION_ENVIRONMENT="prod" CLUSTER_NAME="beta-3" ./deploy_radix_apps.sh
```

This script requires several secret files that contain `RadixRegistration` object configurations to be available in the `keyvault` of the corresponding subscription (i.e. `radixprod` or `radixdev`), as follows.

* radix-api-radixregistration-values

* radix-canary-radixregistration-values

* radix-github-webhook-radixregistration-values

* radix-public-site-values

* radix-web-console-radixregistration-values

## Create aliases

`create_alias.sh` script is used for creating aliases (i.e. ingress objects) for some selected applications  (i.e. Web console, public site, API server, Webhook, canary). Please read the comments in the script file for more details on how to run it. 

This script depends on configuration files (one config for aliasing each application): `alias_config_console.sh`, `alias_config_public_site.sh`, `alias_config_api.sh`, `alias_config_webhook.sh`, `alias_config_canary.sh`.

A simple example to run the script is as follows.

```
RADIX_ALIAS_CONFIG_VARS_PATH=./alias_config_console.sh ./create_alias.sh
```
