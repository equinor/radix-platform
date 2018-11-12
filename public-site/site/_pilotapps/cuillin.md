---
title: Cuillin Predictions
layout: document
parent: ['Documentation', '../documentation.html']
toc: true
---

_Predictions based on rock images from wells._

### Contacts
  - Xiaopeng Liao

### Sources
  - https://github.com/Statoil/cuillin-predictions-browser (main app)
  - https://github.com/Statoil/node-streamgraph (dependency)

### Additional info

Application is today running on Amazon Node.

The full solution has three components:
  - Two CIFS/SMB file shares with terabytes of rock images. (`J` and `K`)
  - A machine learning application that processes the rock images and stores the results on one of the file shares. **This application has to run on AWS due to GPU requirements.**
  - A NodeJS server which serves the rock images and analysis results to a JS frontend. **This is what we will onboard to STaaS**

The file shares mounted via the following lines in `/etc/fstab`:

```
//10.36.32.107/j /data-share/j cifs ro,nocase,credentials=/etc/credentials.data-share 0 0
//10.36.32.107/k /data-share/k cifs ro,nocase,credentials=/etc/credentials.data-share 0 0
```

`/etc/credentials.data-share` (readable only by root) contains the username and password in the form

```
username=[...]
password=[...]
```

### Build process gotchas

The `npm install` process triggers the download of a dependency from a second private repo (i.e. outside the main app repo).

Using deploy keys to allow the build to access this would be cumbersome, since those keys would have to be injected into the builder image. Alternatively we can consider using a [GitHub Machine User](https://developer.github.com/v3/guides/managing-deploy-keys/#machine-users) that should be added to all private repos that are to be accessed by the STaaS CI processes.

We made a more in-depth investigation of this topic: [Authentication of dependency requests during build](build-dependency-authentication.md)

Also, if keys need to be injected somehow into the build image, this should be done using a [Docker multi-stage build](https://docs.docker.com/develop/develop-images/multistage-build/), so that the keys used by ''npm install'' are not carried into the final, deployed image.

### Wants

The Cuillin team would like better monitoring and potential scaling.


## Build & deployment experience

[We made a video](https://statoil.slack.com/files/U9NTD5935/FABU19SJD/cuillin.mp4).

## Challenges
  * Jenkins normally only supports one credential to be specified which is used to pull down the source code from git. However, inside Cuillin in packages.json there is a dependency to another package hosted in a private github repo which needs authentication to access.
    * Machine keys vs deploy keys
    * How to get keys into Jenkins and control security both in transit and at rest and get good user experience
    * How to pass keys to Docker build and not have them appear in the final image
  * The files are stored inside an Amazon VPC that can only be accessed via Statoil's internal network, and those files cannot be copied outside of Statoil's network.

## One way that works for our CI/CD pipeline
  - Clone main repo ''git@github.com:Statoil/cuillin-predictions-browser.git''.
  - Clone package.json dependency repo ''git@github.com:Statoil/node-streamgraph.git''. Beware that this repo has a submodule, after cloning do not forget to run ''git submodule init'' and ''git submodule update''. These 2 commands will create the necessary config for submodule stuff (https://git-scm.com/book/en/v2/Git-Tools-Submodules)
  - Create 2 pairs of deploy keys, one public key for each repo. One private key for the main repo stored in Jenkins, one private key for the dependency repo stored in k8s secret. The submodule does not need any key as it is a public repo.