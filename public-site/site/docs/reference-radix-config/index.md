---
title: The radixconfig.yaml file
layout: document
parent: ["Docs", "../../docs.html"]
toc: true
---

# Overview

In order for Radix to configure your application it needs a configuration file. This must be placed in the root of your app repository and be named `radixconfig.yaml`. The file is expected in YAML or JSON format (in either case, it must have the `.yaml` extension).

> Radix only reads `radixconfig.yaml` from the `master` branch. If the file is changed in other branches, those changes will be ignored.

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

`name` needs to match the name given in when registering an application.

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

We also support wildcard branch mapping using `*` and `%`. Examples of this are:

- `feature/*`
- `feature-%`
- `hotfix/**/*`

## `components`

This is where you specify the various components for your application - it needs at least one. Each component needs a `name`; this will be used for building the Docker images (appName-componentName). Source for the component can be; a folder in the repository, a dockerfile or an image.  

Note! `image` config cannot be used in conjunction with the `src` or the `dockerfileName` config.

### `src`

```yaml
spec:
  components:
    - name: frontend
      src: frontend
      ports:
        - name: http
          port: 80
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
          port: 80
    - name: backend
      dockerfileName: backend.Dockerfile
      ports:
        - name: http
          port: 5000
```
An alternative to this is to use the `dockerfileName` setting of the component.

### `image`

An alternative configuration of a component could be to use a publicly available image, this will not trigger any build of the component.  An example of such a configuration would be:

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

### `environmentConfig`

The `environmentConfig` section is to set environment specific settings for each component

#### `replicas`

```yaml
spec:
  components:
    - name: backend
      environmentConfig:
        - environment: prod
          replicas: 2
```

`replicas` can be used to [horizontally scale](https://en.wikipedia.org/wiki/Scalability#Horizontal_and_vertical_scaling) the component. If `replicas` is not set it defaults to `1`.

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
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "200m"
```

The `resources` section of a component can specify how much CPU and memory each component needs. `resources` is used to ensure that each component is allocated enough resources to run as it should. `limits` describes the maximum amount of compute resources allowed. `requests` describes the minimum amount of compute resources required. If `requests` is omitted for a component it defaults to the settings in `limits`. If `limits` is omitted, its value defaults to an implementation-defined value. [More info](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/)

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

An array of objects containing the `environment` name and variables to be set in the component.

Environment variables are defined per Radix environment. In addition to what is defined here, running containers will also have some [variables automatically set by Radix](../topic-runtime-env/#environment-variables).

### `secrets`

```yaml
spec:
  components:
    - name: backend
      secrets:
        - DB_PASS
```

The `secrets` key contains a list of names. Values for these can be set via the Radix Web Console (under each active component within an environment). Each secret must be set on all environments. Secrets are available in the component as environment variables; a component will not be able to start without the secret being set.

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

In the example above, the component **frontend** hosted in environment **prod** will be accessible from both `some.alias.com` and `another.alias.com`, as long as the correct certificate has been set.

Once the configuration is set in `radixconfig.yaml`, two secrets for every external alias will be automatically created for the component: one for the TLS certificate, and one for the private key used to create the certificate.

There is a [detailed guide](../../guides/external-alias/) on how to set up external aliases.

# Example `radixconfig.yaml` file

This example showcases all options; in many cases the defaults will be a good choice instead.

```yaml
apiVersion: radix.equinor.com/v1
kind: RadixApplication
metadata:
  name: myapp
spec:
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
