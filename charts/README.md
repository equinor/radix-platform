# radix-platform helm charts

Here is a collection of helm charts to assist in the setup of the platform. They are referenced from the [scripts](https://github.com/equinor/radix-platform/tree/master/scripts) used for setting up the platform

## radix-registration and radix-pipeline-invocation charts

The `radix-registration` chart takes a value file and creates a RadixRegistration object.

The `radix-pipeline-invocation` chart will start a build and deploy job for a given application. Note that the app-namespace needs to be created in advance. The `radix-operator` should pick up the RadixRegistration object created by `radix-registration` and create the necessary namespaces.

## Deleting a deployment

To remove everything, run:

    helm del --purge myapp
    helm del --purge radix-pipeline-myapp
    helm del $(helm list --short | grep pipeline) --purge
