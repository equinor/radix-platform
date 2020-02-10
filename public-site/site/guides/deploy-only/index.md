---
title: Deploy to Radix using other continuous integration (CI) tool
layout: document
parent: ["Guides", "../../guides.html"]
toc: true
---

> Disclaimer: Please seek advice elsewhere on wether or not github actions and/or github package repository is the right option for you. Both features are new and we have too little experience as an organization to make any recommendations, both in terms of robustness and in terms of cost. A private Azure container registry (ACR) would for instance allow you to set it up with a service account, rather than using your personal account. This document is meant to be a user guide on how to combine these with Radix, as one of many alternatives for running CI outside of Radix.

# Configuring the app

As with a regular application put on Radix, a deploy-only application will need:

- A GitHub repository for our code (only GitHub is supported at the moment)
- A radixconfig.yaml file that defines the running environments. This must be in the root directory of our repository.

We will go over these points below.

# The repository

Unlike a regular Radix application deploy-only you can choose to have:

- Github repository act as a pure configuration repository. That is, source code for the different components resides in other repositories
- Source code resides with the radixconfig

The following documentation will use the second option.

# The radixconfig.yaml file

> Radix only reads radixconfig.yaml from the master branch. If the file is changed in other branches, those changes will be ignored.

One key distinction of a radixconfig file as compared to a regular Radix application is the the components has no source folder set, as there is nothing to build on Radix. Rather it use an image field, with a separate image tag for each environment, as shown below:

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

> I the radixconfig above, there are two tagging strategies; one using a latest tag (i.e. master-latest), and one using a dynamic tag (i.e release-39f1a082), where there is a new tag produced for every build referring to the release tag or the commit sha (in the case above) that the image is produced from. The dynamic tag gives you better control over what runs in the environment, and it allows for promoting older deployments to be the latest deployment, in case there is a need for rolling back.

The second part of the radixconfig which distinguish itself from a regular radix application is the privateImageHubs setting. See [this](../../docs/reference-radix-config/#privateImageHubs) to read more about this section. This allows for the image produced outside of Radix to be pulled down to the Radix cluster.

# Use master branch as a config branch

Set up both environments to deploy from master branch. Both client component and server component has a {imageTagName} appended to the image string, in order to use the imageTagName field in environment config.

```yaml
apiVersion: radix.equinor.com/v1
kind: RadixApplication
metadata:
  name: <your app name>
spec:
  environments:
    - name: dev
      build:
        from: master
    - name: prod
      build:
        from: master
  components:
    - name: client
      image: docker.pkg.github.com/equinor/<repository>/<client-image>:{imageTagName}
      environmentConfig:
        - environment: dev
          imageTagName: to-be-changed
        - environment: prod
          imageTagName: to-be-changed
      ports:
        - name: http
          port: 80
      public: true
    - name: server
      image: docker.pkg.github.com/equinor/<repository>/<server-image>:{imageTagName}
      environmentConfig:
        - environment: dev
          imageTagName: to-be-changed
        - environment: prod
          imageTagName: to-be-changed
      ports:
        - name: http
          port: 8000
      public: false
  dnsAppAlias:
    environment: prod
    component: client
  privateImageHubs:
    docker.pkg.github.com:
      username: <your username>
      email: <your email>
```

# Building using github actions

Create a workflow file under the folder .github/workflows folder. In below workflow we will build new images for development and release branches, but not for master (as it is considered the config branch). Only a commit to the master branch will trigger a change on Radix

```yaml
name: <name of the workflow>
on:
  push:
    branches:
      - development
      - release
jobs:
  build:
    name: build-push-gpr
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v1

      - name: build client component
        run: |
          docker build -t docker.pkg.github.com/equinor/<repository>/<client-image>:${GITHUB_REF##*/}-${{ github.sha }} ./client/

      - name: build server component
        run: |
          docker build -t docker.pkg.github.com/equinor/<repository>/<server-image>:${GITHUB_REF##*/}-${{ github.sha }} ./server/

      - name: Push the image to GPR
        run: |
          echo ${{ secrets.PRIVATE_TOKEN }} | docker login docker.pkg.github.com -u <your user name> --password-stdin
          docker push docker.pkg.github.com/equinor/<repository>/<client-image>:${GITHUB_REF##*/}-${{ github.sha }}
          docker push docker.pkg.github.com/equinor/<repository>/<server-image>:${GITHUB_REF##*/}-${{ github.sha }}
```

# Changing radixconfig on builds from development and release branch, and commit to master

To fully automate deployment to Radix, we need to commit the new image tag to master branch for the corresponding environment. In my example (see link below) we have created a python script to do that. In the script the mapping of branch to environment is added since the Radix config states both environments derive from master branch. **Be careful: if the action was set up to build also on master, the below setup could end up triggering an endless loop**

```python
import sys
from ruamel.yaml import YAML

# Gets environment-branch mapping
def getEnvironmentFromBranch(branch):
  if branch == 'development':
    return 'dev'

  elif branch == 'release':
    return 'prod'

  return ''

# Gets component index from component name
def getComponentIndex(components,name):
  componentIndex = 0
  for component in components:
      if component['name'] == name:
          return componentIndex

      componentIndex += 1

  return -1

# Gets environment index from environment name
def getEnvironmentIndex(environments,name):
  environmentIndex = 0
  for environment in environments:
      if environment['environment'] == name:
          return environmentIndex

      environmentIndex += 1

  return -1

# Main
component = str(sys.argv[1])
branch = str(sys.argv[2])
newTag = str(sys.argv[3])

inp_radixconfig = open("radixconfig.yaml").read()
yaml = YAML()
content = yaml.load(inp_radixconfig)

environment = getEnvironmentFromBranch(branch)
if environment != '':
  componentIndex = getComponentIndex(content['spec']['components'], component)
  environmentIndex = getEnvironmentIndex(content['spec']['components'][componentIndex]['environmentConfig'], environment)

  content['spec']['components'][componentIndex]['environmentConfig'][environmentIndex]['imageTagName'] = newTag

  outp_radixconfig = open("radixconfig.yaml","w")
  yaml.dump(content, outp_radixconfig)
  outp_radixconfig.close()
```

With the python script in the repository, you can add the following steps to your github actions workflow.

```yaml
- uses: actions/checkout@v2-beta
  with:
    ref: master

- name: Modify radixconfig tag for branch
  run: |
    # Install pre-requisite
    python -m pip install --user ruamel.yaml

    # Update client tag for development environment
    python modifyTag.py client ${GITHUB_REF##*/} ${GITHUB_REF##*/}-${{ github.sha }}

    # Update server tag for development environment
    python modifyTag.py server ${GITHUB_REF##*/} ${GITHUB_REF##*/}-${{ github.sha }}

- name: Commit radixconfig to master branch
  run: |
    git config --global user.name '<your username>'
    git config --global user.email '<your username>@users.noreply.github.com'
    git remote set-url origin https://x-access-token:${{ secrets.PRIVATE_TOKEN }}@github.com/${{ github.repository }}
    git commit -am ${GITHUB_REF##*/}-${{ github.sha }}
    git push origin HEAD:master
```

# Configure Radix to use github package

The following config in your radixconfig.yaml file will allow you to set a secret in the web console to pull images from github package repository:

```
  privateImageHubs:
    docker.pkg.github.com:
      username: <your github user>
      email: <your email>
```

Go to developer settings in Github to generate an access token (Enable SSO in order to have it be able to access Equinor organization):

![PersonalAccessToken](PersonalAccessToken.png)

Set the privileges to allow it to create packages:

![ReadAndWritePackages](ReadAndWritePackages.png)

Go to Radix web console to set the secret:

![PrivateImageHubSecret](PrivateImageHubSecret.png)

# Example

See this [example](https://github.com/equinor/radix-example-deploy-only) for how this can be set up.
