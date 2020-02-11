---
title: Deploy to Radix using other continuous integration (CI) tool
layout: document
parent: ["Guides", "../../guides.html"]
toc: true
---

There might be several reasons why you would opt against using Radix as a CICD platform, and just using the CD part of Radix:

- Your application consists of a set of components, with source code hosted in separated repositories
- Your application depends on separate resources, and the deployment to Radix needs to be orchestrated
- Your team has more advanced needs of the CI than the Radix team is able to deliver

# Configuring the app

As with a regular application put on Radix, a deploy-only application will need:

- A GitHub repository for our code (only GitHub is supported at the moment)
- A radixconfig.yaml file that defines the running environments. This must be in the root directory of our repository.

We will go over these points below.

# The repository

Unlike a regular Radix application deploy-only you can choose to have:

- Github repository act as a pure configuration repository. That is, source code for the different components resides in other repositories
- Source code resides with the radixconfig

The following documentation will use the second option. The example repository can be found [here](https://github.com/equinor/radix-example-arm-template)

# The radixconfig.yaml file

> Radix only reads radixconfig.yaml from the master branch. If the file is changed in other branches, those changes will be ignored.

One key distinction of a radixconfig file as compared to a regular Radix application is the the components has no source property set, as there is nothing to build on Radix. Rather it uses an image property, alongside a separate image tag for each environment, as shown below:

```yaml
apiVersion: radix.equinor.com/v1
kind: RadixApplication
metadata:
  name: radix-example-arm-template
spec:
  environments:
  - name: qa
    build:
      from: master
  - name: prod
    build:
      from: release
  components:
  - name: api
    image: docker.pkg.github.com/equinor/radix-example-arm-template/api:{imageTagName}
    ports:
    - name: http
      port: 3000
    publicPort: http
    environmentConfig:
    - environment: qa
      imageTagName: master-latest
    - environment: prod
      imageTagName: release-39f1a082
privateImageHubs:
  docker.pkg.github.com:
    username: <some github user name>
    email: <some email>
```

I the radixconfig above, there are two tagging strategies; one using a latest tag (i.e. master-latest), and one using a dynamic tag (i.e release-39f1a082), where there is a new tag produced for every build referring to the release tag or the commit sha (in the case above) that the image is produced from. The dynamic tag gives you better control over what runs in the environment, and it allows for promoting older deployments to be the latest deployment, in case there is a need for rolling back.

The second part of the radixconfig which distinguish itself from a regular radix application is the privateImageHubs setting. See [this](../../docs/reference-radix-config/#privateImageHubs) to read more about this configuration. In short, it will allow for the image produced outside of Radix to be pulled down to the Radix cluster.

Also what can be said about the configuration above is the branch to environment mapping. Since build of components happens outside of Radix the build -> from configuration looks unnecessary. You could, especially if the repository for the Radix application is a mere configuration repository, have environments unmapped. We will explain later why, in this example, we have opted to have a mapping.

The full syntax of `radixconfig.yaml` is explained in [Radix Config reference](../../docs/reference-radix-config/).

# Registering the application

Registering the Radix application follows the pattern of a regular Radix application, except for that we skip registering a web-hook for the application to avoid it being built on Radix. The mechanism for deploying to Radix will be described in the next section.

# Machine-user token

In a deploy-only scenario you will tell us when to deploy, rather than having the web-hook tell us when changes have occurred in the repository, as for other Radix applications. In order to do that, you will make calls to the Radix API. In order to do that you have two approaches:

- You can authenticate with any user in the application `Administrators` group, and get a token of that user (i.e. az account get-access-token) to communicate with the Radix API
- You can use the machine user token we provide you, as long as you have enabled the machine user to be created for your application

The machine user token you can obtain on the `Configuration` page for your application.

![MachineUserToken](MachineUserToken.png)

By pressing `Regenerate token` button, you invalidates the existing token and you get access to copy a new token into your clipboard.

# Making calls to Radix

With the access token you can make calls to our API through either:

- Calling the API directly ([production API](https://api.radix.equinor.com/swaggerui/) or [playground API](https://api.playground.radix.equinor.com/swaggerui/)), by passing the bearer token (i.e. curl -X GET --header "Authorization: Bearer $token")
- Calling the API though functions in the [Radix CLI](https://github.com/equinor/radix-cli), which allows for simpler access to the API
- Calling the API through [Radix Github Actions](https://github.com/equinor/radix-github-actions). If you have opted for github actions as your CI tool, then calling the Radix API indirectly through the Radix CLI through the Radix github actions could be done. It allows for simpler access to the CLI in your actions workflow.

# Building using other CI (i.e. github actions)

Using github actions you create a workflow file under the folder .github/workflows folder. In below workflow we will build new images for master (qa environment) and release (prod environment) branches. There are a couple of github secrets the workflow make use of in the workflow:

- `K8S_CREDENTIALS` - This is the token used for accessing Radix. In this example we are using the machine user token provided with the application. The name of the secret can be any name. However, the environment variable needs to be `APP_SERVICE_ACCOUNT_TOKEN`, as this is what the Radix CLI expect the environment variable to be named
- `PRIVATE_TOKEN` - The private token is used for publishing a package to github package repository. The name is irrelevant. It is a personal access token that you configure for your github user. In this example we use the same token for producing the package, as we do for giving Radix access to pull the image to the cluster

## Configuring a personal access token

Go to developer settings in Github to generate an access token (Enable SSO in order to have it be able to access Equinor organization):

![PersonalAccessToken](PersonalAccessToken.png)

Set the privileges to allow it to create packages:

![ReadAndWritePackages](ReadAndWritePackages.png)

## The workflow

In the below workflow we have a series of steps. They are:

- `Set default image tag` - In the example we have a fixed tag for qa environment (i.e. master-latest) while we have a dynamic tag for prod environment. This step sets the default tag for qa environment, or any other environment we choose to add with a latest tagging strategy
- `Override image tag for prod environment` - Gives a dynamic image tag for production
- `Build API component` - Building is now done outside of Radix
- `Push the image to GPR` - Pushes a package to Github package repository using the `PRIVATE_TOKEN` (personal access token)
- `Prepare for committing new tag to radix config on master` - Since we are using the dynamic tagging for prod environment, we have to commit to master a version of the radixconfig.yaml holding the newly produced tag. This step checks out master  branch of the repository
- `Modify radixconfig tag for production on master branch` - This step calls a [custom script](https://github.com/equinor/radix-example-arm-template/blob/master/hack/modifyTag.py) to modify the tag in radixconfig and the commits and push the change on master
- `Get environment from branch` - This steps calls a utility function in the CLI for obtaining the environment based on the current brach from the branch-environment mapping in the radixconfig of the repository
- `Deploy API on Radix` - This step calls the CLI function, which calls the deploy pipeline function of the Radix API for running the deploy pipeline. It uses the output of the previous step to tell Radix which environment it should deploy to. Note that is using `development` context to contact the API in the development cluster. Similarly if context is `playground` it will contact API in playground cluster. If you remove this entirely, it will default to `production` context

> Note that the push of the dynamic image tag of the prod environment to master branch creates a side-effect of building the QA environment again, as this is mapped to master. This shows that maybe for deploy-only master branch should not be mapped to any environment (neither in the radixconfig, nor in the github actions workflow)

```yaml
name: CI

on:
  push:
    branches:
      - master
      - release

jobs:
  build:
    name: deploy
    runs-on: ubuntu-latest
    env:
      APP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.K8S_CREDENTIALS }}
    steps:
      - uses: actions/checkout@v1
      - name: Set default image tag
        run: |
          echo ::set-env name=IMAGE_TAG::$(echo ${GITHUB_REF##*/}-latest)
      - name: Override image tag for prod environment
        if: github.ref == 'refs/heads/release'
        run: |
          echo ::set-env name=IMAGE_TAG::$(echo ${GITHUB_REF##*/}-${GITHUB_SHA::8})
      - name: Build API component
        run: |
          docker build -t docker.pkg.github.com/equinor/radix-example-arm-template/api:$IMAGE_TAG ./todoapi/
      - name: Push the image to GPR
        run: |
          echo ${{ secrets.PRIVATE_TOKEN }} | docker login docker.pkg.github.com -u <any-github-user-name> --password-stdin
          docker push docker.pkg.github.com/equinor/radix-example-arm-template/api:$IMAGE_TAG
      - name: Prepare for committing new tag to radix config on master
        uses: actions/checkout@v2-beta
        with:
          ref: master
      - name: Modify radixconfig tag for production on master branch
        if: github.ref == 'refs/heads/release'
        run: |
          # Install pre-requisite
          python -m pip install --user ruamel.yaml
          python hack/modifyTag.py api ${GITHUB_REF##*/} $IMAGE_TAG
          git config --global user.name 'ingeknudsen'
          git config --global user.email 'ingeknudsen@users.noreply.github.com'
          git remote set-url origin https://x-access-token:${{ secrets.PRIVATE_TOKEN }}@github.com/${{ github.repository }}
          git commit -am $IMAGE_TAG
          git push origin HEAD:master
      - name: Get environment from branch
        id: getEnvironment
        uses: equinor/radix-github-actions@master
        with:
          args: >
            get-config branch-environment
            -b ${GITHUB_REF##*/}
      - name: Deploy API on Radix
        uses: equinor/radix-github-actions@master
        with:
          args: >
            trigger
            deploy
            --context development
            -e ${{ steps.getEnvironment.outputs.result }}
            -f
```


# Configure Radix to use github package

Go to Radix web console to set the secret, which will be the personal access token you have created which have access to read packages in the Equinor organization:

![PrivateImageHubSecret](PrivateImageHubSecret.png)

# Coordinating workflow

The workflow above maybe is not a good case for moving your CI workflow out of Radix. In the example repository that we have used for this documentation we are setting secrets in Radix to be values associated with resources in Azure created for the application. The additional workflow steps are shown below. They are:

- Log into Azure - See [here](https://github.com/Azure/login) for documentation on what the `AZURE_CREDENTIALS` should contain
- `Get instrumentation key and connection string` - Obtains and passes on to subsequent steps the secret values to be set in Radix. Note that you should `add-mask` to any secret that you pass on in the workflow, to ensure that it is not exposed in the log of the workflow
- `Set instrumentation key as secret` - Takes one of the secrets passed on from the previous steps and set the secret for the application, for the environment this branch is mapped to (in the `development` cluster)
- `Set connection string as secret` - Sets the second secret value

```yaml
      - uses: Azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - name: Get instrumentation key and connection string
        id: getSecrets
        run: |
          RESOURCE_GROUP=db-api-radix-${{ steps.getEnvironment.outputs.result }}
          INSTRUMENTATIONKEY=$(az group deployment show -g ${RESOURCE_GROUP} -n azuredeploy --query properties.outputs.appInsightInstrumentationKey.value)
          CONNECTION_STRING=$(az group deployment show -g ${RESOURCE_GROUP} -n azuredeploy --query properties.outputs.storageConnectionString.value)
          echo ::set-output name=instrumentationKey::$(echo ${INSTRUMENTATIONKEY})
          echo ::set-output name=connectionString::$(echo ${CONNECTION_STRING})
          echo ::add-mask::${INSTRUMENTATIONKEY}
          echo ::add-mask::${CONNECTION_STRING}
      - name: Set instrumentation key as secret
        uses: equinor/radix-github-actions@master
        with:
          args: >
            set environment-secret
            --context development
            -e ${{ steps.getEnvironment.outputs.result }}
            --component api
            -s APPINSIGHTS_INSTRUMENTATIONKEY
            -v '${{ steps.getSecrets.outputs.instrumentationKey }}'
      - name: Set connection string as secret
        uses: equinor/radix-github-actions@master
        with:
          args: >
            set environment-secret
            --context development
            -e ${{ steps.getEnvironment.outputs.result }}
            --component api
            -s AZURE_STORAGE_CONNECTION_STRING
            -v '${{ steps.getSecrets.outputs.connectionString }}'

```

> Disclaimer: Please seek advice elsewhere on wether or not github actions and/or github package repository is the right option for you. Both features are new and we have too little experience as an organization to make any recommendations, both in terms of robustness and in terms of cost. A private Azure container registry (ACR) would for instance allow you to set it up with a service account, rather than using your personal account. This document is meant to be a user guide on how to combine these with Radix, as one of many alternatives for running CI outside of Radix.