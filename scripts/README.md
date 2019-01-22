# Radix Infrastructure Provisioning

This `script` directory is created specifically for provisioning the Radix infrastructure on Azure.

## Create infrastructure

`install_infrastructure.sh` script is used for creating all dependencies that a cluster needs (e.g. keyvault, dns). Please read the comments in the script file for more details on how to run it.

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

## Deploy Radix applications

`deploy_radix_apps.sh` script is used for installing Radix applications (e.g. API server, Webhook). Please read the comments in the script file for more details on how to run it. A simple example to run the script is as follows.

```
SUBSCRIPTION_ENVIRONMENT="prod" CLUSTER_NAME="beta-3" ./deploy_radix_apps.sh
```

## Create aliases

`create_alias.sh` script is used for creating aliases (i.e. ingress objects) for some selected applications  (i.e. Web console, public site, API server, Webhook, canary). Please read the comments in the script file for more details on how to run it. 

This script depends on configuration files (one config for aliasing each application): `alias_config_console.sh`, `alias_config_public_site.sh`, `alias_config_api.sh`, `alias_config_webhook.sh`, `alias_config_canary.sh`.

A simple example to run the script is as follows.

```
RADIX_ALIAS_CONFIG_VARS_PATH=./alias_config_console.sh ./create_alias.sh
```