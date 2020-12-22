---
title: The radixconfig.yaml file
layout: document
parent: ["Docs", "../../docs.html"]
toc: true
---

# Overview

In order for Radix to configure your application it needs a configuration file. This must be placed in the root of your app repository and be named `radixconfig.yaml`. The file is expected in YAML or JSON format (in either case, it must have the `.yaml` extension).

> Radix only reads `radixconfig.yaml` from the branch we set as the `Config Branch` in the application registration form. If the file is changed in other branches, those changes will be ignored. The `Config Branch` must be mapped to an environment in `radixconfig.yaml`

The basic format of the file is this; the configuration keys are explained in the Reference section below:

```yaml
apiVersion: radix.equinor.com/v1
kind: RadixApplication
metadata: ...
spec: ...
```

# Reference

## `name`

```yaml
apiVersion: radix.equinor.com/v1
kind: RadixApplication
metadata:
  name: myapp
spec:
```

`name` needs to match the name given in when registering an application. Only lowercase characters are allowed. If the name supplied in the configuration contains uppercase characters, a warning will be logged and the name will be automatically converted to lowercase.

## `build`

```yaml
spec:
  build:
    secrets:
      - SECRET_1
      - SECRET_2
```

The `build` section of the spec contains configuration needed during build (CI part) of the components. In this section you can specify build secrets, which is needed when pulling from locked registries, or cloning from locked repositories.

Add the secrets to Radix config `radixconfig.yaml` in the branch defined as `Config Branch` for your application. This will trigger a new build. This build will fail as no specified build secret has been set. You will now be able to set the secret **values** in the configuration section of your app in the Radix Web Console.

To ensure that multiline build secrets are handled ok by the build, **all** build secrets are passed base-64 encoded. This means that you will need to base-64 decode them before use:

```
FROM node:10.5.0-alpine

# Install base64
RUN apk update && \
    apk add coreutils

ARG SECRET_1

RUN echo "${SECRET_1}" | base64 --decode

```

## `environments`

```yaml
spec:
  environments:
    - name: dev
      build:
        from: master
    - name: prod
      build:
        from: release
```

The `environments` section of the spec lists the environments for the application and the branch each environment will build from. If you omit the `build.from` key for the environment, no automatic builds or deployments will be created. This configuration is useful for a promotion-based [workflow](../../guides/workflows/). 

We also support wildcard branch mapping using `*` and `?`. Examples of this are:

- `feature/*`
- `feature-?`
- `hotfix/**/*`

> The `Config Branch` set in the application registration form **must** be mapped to one of the `environments`

## `components`

This is where you specify the various components for your application - it needs at least one. Each component needs a `name`; this will be used for building the Docker images (appName-componentName). Source for the component can be; a folder in the repository, a dockerfile or an image.

> Note! `image` config cannot be used in conjunction with the `src` or the `dockerfileName` config.

### `src`

```yaml
spec:
  components:
    - name: frontend
      src: frontend
      ports:
        - name: http
          port: 8080
    - name: backend
      src: backend
      ports:
        - name: http
          port: 5000
```

Specify `src` for a folder (relative to the repository root) where the `Dockerfile` of the component can be found and used for building on the platform. It needs a list of `ports` exposed by the component, which map with the ports exposed in the `Dockerfile`. An alternative to this is to use the `dockerfileName` setting of the component.

### `dockerfileName`

```yaml
spec:
  components:
    - name: frontend
      dockerfileName: frontend.Dockerfile
      ports:
        - name: http
          port: 8080
    - name: backend
      dockerfileName: backend.Dockerfile
      ports:
        - name: http
          port: 5000
```

An alternative to this is to use the `dockerfileName` setting of the component.

### `image`

An alternative configuration of a component could be to use a publicly available image, this will not trigger any build of the component. An example of such a configuration would be:

```yaml
spec:
  components:
    - name: redis
      image: redis:5.0-alpine
    - name: swagger-ui
      image: swaggerapi/swagger-ui
      ports:
        - name: http
          port: 8080
      publicPort: http
```

### `publicPort`

```yaml
spec:
  components:
    - name: frontend
      publicPort: http
```

The `publicPort` field of a component, if set to `<PORT_NAME>`, is used to make the component accessible on the internet by generating a public endpoint. Any component without `publicPort: <PORT_NAME>` can only be accessed from another component in the app. If specified, the `<PORT_NAME>` should exist in the `ports` field.

### `ingressConfiguration`

```yaml
spec:
  components:
    - name: frontend
      ingressConfiguration:
        - websocketfriendly
```

The `ingressConfiguration` field of a component will add extra configuration by [annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/) to the Nginx ingress, useful for a particular scenario.

> Note that the settings affect the connections with the public component, not between a public and a private component.

- `websocketfriendly` will change connection timeout to 1 hour for the component.
- `stickysessions` will change load balancing of the ingress to route to a single replica.
- `leastconnectedlb` will ensure that connections will be routed to the replica with least amount of load

See [this](https://github.com/equinor/radix-operator/blob/b828195f1b3c718d5a48e31d0bafe0435857f5bf/charts/radix-operator/values.yaml#L58) for more information on what annotations will be put on the ingress, given the configuration.

### `alwaysPullImageOnDeploy`

```yaml
spec:
  components:
    - name: api
      image: docker.pkg.github.com/equinor/my-app/api:latest
      alwaysPullImageOnDeploy: false
```

Only relevant for teams that uses another CI tool than Radix and static tags. See [deploy-only](../../guides/deploy-only/#updating-deployments-on-static-tags) for more information.

### `secrets`

```yaml
spec:
  components:
    - name: backend
      secrets:
        - DB_PASS
```

The `secrets` key contains a list of names. Values for these can be set via the Radix Web Console (under each active component within an environment). Each secret must be set on all environments. Secrets are available in the component as environment variables; a component will not be able to start without the secret being set.

### `resources` (common)

```yaml
spec:
  components:
    - name: backend
      resources:
        requests:
          memory: "64Mi"
          cpu: "50m"
        limits:
          memory: "64Mi"
          cpu: "1000m"
```

The `resources` section specifies how much CPU and memory each component needs, that are shared among all Radix environments in a component. These common resources are overriden by environment-specific resources.

### `variables` (common)

```yaml
spec:
  components:
    - name: backend
      variables:
        DB_NAME: my-db
```

The `variables` key contains environment variable names and their values, that are shared among all Radix environments in a component. These common environment variables are overriden by environment-specific environment variables that have exactly same names.

### `environmentConfig`

The `environmentConfig` section is to set environment-specific settings for each component.

#### `replicas`

```yaml
spec:
  components:
    - name: backend
      environmentConfig:
        - environment: prod
          replicas: 2
```

`replicas` can be used to [horizontally scale](https://en.wikipedia.org/wiki/Scalability#Horizontal_and_vertical_scaling) the component. If `replicas` is not set, it defaults to `1`. If `replicas` is set to `0`, the component will not be deployed (i.e. stopped).

#### `monitoring`

```yaml
spec:
  components:
    - name: frontend
      environmentConfig:
        - environment: prod
          monitoring: true
```

The `monitoring` field of a component environment config, if set to `true`, is used to expose custom application metrics in the Radix monitoring dashboards. It is expected that the component provides a `/metrics` endpoint: this will be queried periodically (every five seconds) by an instance of [Prometheus](https://prometheus.io/) running within Radix. General metrics, such as resource usage, will always be available in monitors, regardless of this being set.

#### `resources`

```yaml
spec:
  components:
    - name: frontend
      environmentConfig:
        - environment: prod
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "2000m"
```

The `resources` section specifies how much CPU and memory each component needs, that are defined per Radix environment in a component. `resources` is used to ensure that each component is allocated enough resources to run as it should. `limits` describes the maximum amount of compute resources allowed. `requests` describes the minimum amount of compute resources required. If `requests` is omitted for a component it defaults to the settings in `limits`. If `limits` is omitted, its value defaults to an implementation-defined value. [More info](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/)

For shared resources across Radix environments, refer to [common resources](./#resources-common).

#### `variables`

```yaml
spec:
  components:
    - name: backend
      environmentConfig:
        - environment: dev
          variables:
            DB_HOST: "db-dev"
            DB_PORT: "1234"
        - environment: prod
          variables:
            DB_HOST: "db-prod"
            DB_PORT: "9876"
```

The `variables` key contains environment variable names and their values, that are defined per Radix environment in a component. In addition to what is defined here, running containers will also have some [environment variables automatically set by Radix](../topic-runtime-env/#environment-variables).

For shared environment variables across Radix environments, refer to [common environment variables](./#variables-common).

#### `horizontalScaling`

```yaml
spec:
  components:
    - name: backend
      environmentConfig:
        - environment: prod
          horizontalScaling:
            minReplicas: 2
            maxReplicas: 6
```

The `horizontalScaling` field of a component environment config is used for enabling automatic scaling of the component in the environment. This field is optional, and if set, it will override `replicas` value of the component. One exception is when the `replicas` value is set to `0` (i.e. the component is stopped), the `horizontalScaling` config will not be used.

The `horizontalScaling` field contains two sub-fields: `minReplicas` and `maxReplicas`, that specify the minimum and maximum number of replicas for a component, respectively. The value of `minReplicas` must strictly be smaller or equal to the value of `maxReplicas`.

#### `imageTagName`

The `imageTagName` allows for flexible configuration of fixed images, built outside of Radix, to be configured with separate tag for each environment.

```yaml
components:
  - name: backend
    image: docker.pkg.github.com/equinor/myapp/backend:{imageTagName}
    environmentConfig:
      - environment: qa
        imageTagName: master-latest
      - environment: prod
        imageTagName: release-39f1a082
```

> See [this](../../guides/deploy-only/) guide on how make use of `imageTagName` in a deploy-only scenario.

#### `volumeMounts`

```yaml
spec:
  components:
    - name: backend
      environmentConfig:
        - environment: prod
          volumeMounts:
            - type: blob
              name: volume-name
              container: container-name
              path: /path/in/container/to/mount/to
```

The `volumeMounts` field of a component environment config is used to be able to mount a blob container into the running container.

The `volumeMounts` field contains the following sub-fields: `type` field can currently only be set to `blob`, `name` is the name of the volume (unique within `volumeMounts` list), `container` is the name of the blob container, and `path` is the folder to mount to inside the running component.

> See [this](../../guides/volume-mounts/) guide on how make use of `volumeMounts`.

## `dnsAppAlias`

```yaml
spec:
  dnsAppAlias:
    environment: prod
    component: frontend
```

As a convenience for nicer URLs, `dnsAppAlias` creates a DNS alias in the form of `<app-name>.app.radix.equinor.com` for the specified environment and component.

In the example above, the component **frontend** hosted in environment **prod** will be accessible from `myapp.app.radix.equinor.com`, in addition to the default endpoint provided for the frontend component, `frontend-myapp-prod.<clustername>.radix.equinor.com`.

## `dnsExternalAlias`

```yaml
spec:
  dnsExternalAlias:
    - alias: some.alias.com
      environment: prod
      component: frontend
    - alias: another.alias.com
      environment: prod
      component: frontend
```

It is possible to have multiple custom DNS aliases (i.e. to choose your own custom domains) for the application. The `dnsExternalAlias` needs to point to a component marked as public. It can be any domain name, which can in turn be used for public URLs to access the application — as long as the application developer provides a valid certificate for the alias. 

If public component is a `proxy` (like `oauth-proxy` in [this example](https://github.com/equinor/radix-example-oauth-proxy)), which is used as a public component, routing requests to `frontend` component - `dnsExternAlias.component` should point to this `proxy` component.   

In the example above, the component **frontend** hosted in environment **prod** will be accessible from both `some.alias.com` and `another.alias.com`, as long as the correct certificate has been set.

Once the configuration is set in `radixconfig.yaml`, two secrets for every external alias will be automatically created for the component: one for the TLS certificate, and one for the private key used to create the certificate.

There is a [detailed guide](../../guides/external-alias/) on how to set up external aliases.

## `privateImageHubs`

```yaml
spec:
  components:
    - name: webserver
      image: privaterepodeleteme.azurecr.io/nginx:latest
  privateImageHubs:
    privaterepodeleteme.azurecr.io:
      username: 23452345-3d71-44a7-8476-50e8b281abbc
      email: radix@statoilsrm.onmicrosoft.com
    privaterepodeleteme2.azurecr.io:
      username: 23423424-3d71-44a7-8476-50e8b281abb2
      email: radix@statoilsrm.onmicrosoft.com
```

It is possible to pull images from private image hubs during deployment for an application. This means that you can add a reference to a private image hub in radixconfig.yaml file using the `image:` tag. See example above. A `password` for these must be set via the Radix Web Console (under Configuration -> Private image hubs).

To get more information on how to connect to a private Azure container registry (ACR), see the following [guide](https://thorsten-hans.com/how-to-use-private-azure-container-registry-with-kubernetes). The chapter `Provisioning an Azure Container Registry` provide information on how to get service principle `username` and `password`. It is also possible to create a Service Principle in Azure AD, and then manually grant it access to your ACR.

> See [guide](../../guides/deploy-only/) on how make use of `privateImageHubs` in a deploy-only scenario.

# Example `radixconfig.yaml` file

This example showcases all options; in many cases the defaults will be a good choice instead.

```yaml
apiVersion: radix.equinor.com/v1
kind: RadixApplication
metadata:
  name: myapp
spec:
  build:
    secrets:
      - SECRET_1
      - SECRET_2
  environments:
    - name: dev
      build:
        from: master
    - name: prod
  components:
    - name: frontend
      src: frontend
      ports:
        - name: http
          port: 80
      publicPort: http
      environmentConfig:
        - environment: prod
          monitoring: true
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "200m"
    - name: backend
      src: backend
      ports:
        - name: http
          port: 5000
      environmentConfig:
        - environment: dev
          variables:
            DB_HOST: "db-dev"
            DB_PORT: "1234"
        - environment: prod
          replicas: 2
          variables:
            DB_HOST: "db-prod"
            DB_PORT: "9876"
      secrets:
        - DB_PASS
  dnsAppAlias:
    environment: prod
    component: frontend
  dnsExternalAlias:
    - alias: some.alias.com
      environment: prod
      component: frontend
    - alias: another.alias.com
      environment: prod
      component: frontend
```
