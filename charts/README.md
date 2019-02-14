# radix-platform helm charts

Here is a collection of platform-wide helm charts

## radix-stage0 and radix-stage1 charts

The `radix-stage0`containes prerequisites for the components in `radix-stage1` helm chart, which aims to be the top level umbrella chart that will install as many of the base components as possible. Such as:

- nginx
- cert-manager
- prometheus
- kubed
- humio

## radix-registration and radix-pipeline-invocation charts

The `radix-registration` chart takes a value file and creates a RadixRegistration object.

The `radix-pipeline-invocation` chart will start a build and deploy job for a given application. Note that the app-namespace needs to be created in advance. The `radix-operator` should pick up the RadixRegistration object created by `radix-registration` and create the necessary namespaces.

## Deleting a deployment

To remove everything, run:

    helm del --purge myapp
    helm del --purge radix-pipeline-myapp
    helm del $(helm list --short | grep pipeline) --purge
