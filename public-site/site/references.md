---
title: References
layout: document
toc: true
---

# Radix Config Explained

In order for Radix to configure your application it needs the RadixConfig file.

This file needs to live in the root of your repository and be named radixconfig.yaml. The name of the application needs to match the name given in the registration.

## Name

```yaml
apiVersion: radix.equinor.com/v1
kind: RadixApplication
metadata:
  name: myapp
spec:
```

**Name** needs to match the name given in when registering an application.

## Environments

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

The **environments** section of the spec lists the environments for the application and the branch each environment will build from. If you omit the **build from** for the environment, the environment will never get built, which would only make sense in a promotion [workflow](guides#workflows).

## Components

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
      replicas: 2
      ports:
      - name: http
          port: 5000
```

This is where you specify the various components for your application - it needs at least one. The **component** need a name, this will be used for building the images (appName-componentName). It needs a **src**, which is the folder where the Dockerfile of the component can be found and used for building on the platform. It need a list of **ports** which exposed by your component, which maps with the ports exposed in the Dockerfile. You might set the **replicas** field to horizontally scale your component. If number of **replicas** is not set then it defaults to 1.

## Public

```yaml
spec:
  components:
    - name: frontend
      public: true
```

The **public** field of the **components** is to make the component accessible from outside, on the internet, by generating a public endpoint for the component, if set to true. Any component without this field set to true can only be accessed from another component in the app.

## Monitoring

```yaml
spec:
  components:
    - name: frontend
      monitoring: true
```

The **monitoring** field of the **components** is to expose custom application metrics to your monitoring dashboards, if set to true. Then Prometheus will pull from a /metrics endpoint of your component. General metrics, such as resource usage, will always be available in monitors, regardless of this being set

## Resources

```yaml
spec:
  components:
    - name: frontend
      resources:
        requests:
          memory: "64Mi"
          cpu: "100m"
        limits:
          memory: "128Mi"
          cpu: "200m"
```

The **resources** section of the **components** can specify how much CPU and memory each component needs. **Resources** is used to ensure that each component is allocated enough resources to run as it should. **Limits** describes the maximum amount of compute resources allowed. **Requests** describes the minimum amount of compute resources required. If **requests** is omitted for a container, it defaults to **limits** if that is explicitly specified, otherwise to an implementation-defined value. [More info](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/)

## Environment Variables

```yaml
spec:
  components:
    - name: backend
      environmentVariables:
        - environment: dev
          variables:
            DB_HOST: "db-dev"
            DB_PORT: "1234"
        - environment: prod
          variables:
            DB_HOST: "db-prod"
            DB_PORT: "9876"
```

An array of objects containing environment name and variables to be set inside the running container.

By default, each application container will have the following default environment variables. Environment variables are defined per environment

- RADIX_APP
- RADIX_CLUSTERNAME
- RADIX_CONTAINER_REGISTRY
- RADIX_COMPONENT
- RADIX_ENVIRONMENT
- RADIX_DNS_ZONE
- RADIX_PORTS (only available if set in the config)
- RADIX_PORT_NAMES (only available if set in the config)
- RADIX_PUBLIC_DOMAIN_NAME (if public equals true is set)

## Secrets

```yaml
spec:
  components:
    - name: backend
      secrets:
        - DB_PASS
```

The **secrets** is a list of names where values can be set in the Radix Web Console. They are available to be set on all environments. They will be accessible in the container as environment variables. A component will not be able to start without the secret being set.

## DNSAppAlias

```yaml
spec:
  dnsAppAlias:
    environment: prod
    component: frontend
```

**dnsAppAlias** creates an alias in the form of \<app-name\>.app.radix.equinor.com for the specified environment and component.

In the example above, the component frontend hosted in environment prod, will be accessible from myapp.app.radix.equinor.com, in addition to the default endpoint provided for the frontend component, frontend-myapp-prod.\<clustername\>.dev.radix.equinor.com

## Complete Config File

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
      public: true
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
      replicas: 2
      ports:
        - name: http
          port: 5000
      environmentVariables:
        - environment: dev
          variables:
            DB_HOST: "db-dev"
            DB_PORT: "1234"
        - environment: prod
          variables:
            DB_HOST: "db-prod"
            DB_PORT: "9876"
      secrets:
        - DB_PASS
  dnsAppAlias:
    environment: prod
    component: frontend
```

# Security

## Role Based Access Control

Membership in the 'Radix Platform User' AD group grants access to

- Radix Platform Web Console
- Grafana Dashboard (Monitoring)

Access to manage each application are limited to the members of the AD group provided on the application registration <sup><sup>1</sup></sup>. Management of applications can be e.g. deleting the application from the Radix Platform, view jobs and logs. 

If no AD group is provided during the registration, the application will be available to all Radix users (members of the 'Radix Platform Users' AD group).

We point out that this is **not** to control the access within the application itself.

## Authentication

It is important to know that authentication is something that is considered to be handled outside of the Radix platform, and not by the Radix platform itself. That is, each team managing an application hosted on Radix platform will be responsible for securing their own application.

For an example of authentication in the app using AD have a look at [Omnia Radix Auth Example](https://github.com/equinor/radix-example-auth)

# Best Practice Dockerfiles

# App Examples

<sup><sup>1</sup></sup> Currently all application are listed, this is a known problem and will be fixed. However, only applications a user has access to can be viewed in a detail view.