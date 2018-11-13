# radix-platform helm charts

Here is a collection of platform-wide helm charts

## radix-platform chart

The `radix-platform` helm chart aims to be the top level umbrella chart that will install as many of the base components as possible.

## radix-registration and radix-pipeline-invocation charts

The `radix-registration` chart takes a value file and creates a RadixRegistration object.

The `radix-pipeline-invocation` chart will start a build and deploy job for a given application. Note that the app-namespace needs to be created in advance. The `radix-operator` should pick up the RadixRegistration object created by `radix-registration` and create the necessary namespaces.

### Preparing a component for deployment with the radix-charts

Create a local copy of [radix-registration/values.yaml](radix-registration/values.yaml) and fill out all the fields. Call it something like `myapp-radixregistration-values.yaml`.

Store this file in Azure KeyVault for later use, change --file and --name params:

    az keyvault secret set --file myapp-radixregistration-values.yaml --name myapp-radixregistration-values --vault-name radix-boot-dev-vault

### Deploying an application with the radix-charts

Refresh authentication tokens for accessing Azure Container Registry (ACR):

    az acr helm repo add --name radixdev && helm repo update

Download the secrets required to get the source-code:

    az keyvault secret download -f myapp-radixregistration-values.yaml -n myapp-radixregistration-values --vault-name radix-boot-dev-vault

Create the RadixRegistration object in Kubernetes, replace `myapp` and `myapp-radixregistration-values.yaml`:

    helm upgrade --install myapp -f myapp-radixregistration-values.yaml radixdev/radix-registration

Delete the values file containing secrets so they don't leak anywhere:

    rm myapp-radixregistration-values.yaml

In the background now `radix-operator` should have created the necessary namespaces etc to allow us to run the actual build and deploy jobs.

Create a Kubernetes job with an invocation of the pipeline, replace `--install` and `name` and `cloneURL` fields:

    helm upgrade --install radix-pipeline-myapp radixdev/radix-pipeline-invocation --set name="myapp" --set cloneURL="git@github.com:Statoil/myapp.git" --set cloneBranch="master"

### Deleting a deployment

To remove everything, run:

    helm del --purge myapp
    helm del --purge radix-pipeline-myapp
