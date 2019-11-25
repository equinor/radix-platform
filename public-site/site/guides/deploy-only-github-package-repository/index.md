---
title: Deploy to Radix using github actions and github package
layout: document
parent: ['Guides', '../../guides.html']
toc: true
---

Disclaimer: Please seek advice elsewhere on wether or not github actions and/or github package repository is the right option for you. This document is meant to be a user guide on how to combine these with Radix.

# Building using github actions

Create a workflow file under the folder .github/workflows folder. In below workflow we generate branch latest image tags (i.e. master-latest or release-latest). Any new deployment to environment will trigger a new pull of the image.

```
name: <name of the workflow>
on:
  push:
    branches:
      - master
      - release
jobs:
  build:
    name: build-push-gpr
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v1

      - run: |
          docker build -t docker.pkg.github.com/equinor/<your repository>/<image name>:${GITHUB_REF##*/}-latest .

      - name: Push the image to GPR
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | docker login docker.pkg.github.com -u publisher --password-stdin
          docker push docker.pkg.github.com/equinor/<your repository>/<image name>:${GITHUB_REF##*/}-latest
```

# Set up Radix to use github package

Add the following to your radixconfig.yaml file:

```
  privateImageHubs:
    docker.pkg.github.com:
      username: <your github user>
      email: <your email>
```

# Generate a personal token

Go to developer settings in Github to generate an access token (Enable SSO in order to have it be able to access Equinor organization):

![PersonalAccessToken](PersonalAccessToken.png)

Set the privileges to allow it to create packages:

![ReadAndWritePackages](ReadAndWritePackages.png)

# Set the access token in Radix web console

Go to Radix web console to set the secret:

![PrivateImageHubSecret](PrivateImageHubSecret.png)

If the radixconfig the looks like this:

```
apiVersion: "radix.equinor.com/v1"
kind: RadixApplication
metadata:
  name: <your app name>
spec:
  environments:
    - name: prod
      build:
        from: master
  components:
    - name: your-component
      image: docker.pkg.github.com/equinor/<your repository>/<image name>:master-latest
      ports:
        - name: http
          port: 8080
  dnsAppAlias:
    environment: prod
    component: your-component
  privateImageHubs:
    docker.pkg.github.com:
      username: <your username>
      email: <your email>
```

Then a change to the master branch would trigger the action which produces a new image to package repository as well as a new deployment on Radix. For now the deployment may be made before the new latest image is produced, so you may need to [restart](guides/component-start-stop-restart/) the app to ensure that it is running with the latest master-latest image.
