---
title: Authentication of dependency requests during build
layout: document
toc: true
---

The build step of an application will usually trigger the download of dependencies. If those dependencies originate from a private Git repository (e.g. ''ssh+git:'' dependencies in NPM) then a method of authenticating against the repository is necessary during the build.

This is potentially a common development scenario, whereby a reusable component is placed in its own (private) repository and developed in parallel with another project.

## Possible solutions

### A. Enforce usage of deploy keys for all dependencies

Each dependency will need to provide its deploy key to the project (but it is not necessary to use multiple deploy keys for dependency/project combinations).

* Pros
    * Better pattern for security
    * Limited area of exposure (if a key is compromised, only the corresponding repo can be accessed)
* Cons
    * Repo owners must manage their deploys keys, even if their project is just a dependency
    * STaaS platform has to generate a deploy key for every private repo
    * Private keys are available to Docker, and possibly exploitable by a malicious Dockerfile
* Unsolved issues
    * Not clear how to inject the correct keys into the build process — i.e. how would npm/ssh use the correct key for a specific dependency?

### B. Use a Machine User

We would create a single STaaS GitHub account to be used for automation for all projects. This account can be added to any private repo that needs to be accessed during builds (both for projects in STaaS and their private dependencies). By defining a user SSH key for this account the build process would be able to access all repositories the user is a part of.

* Pros
    * Easy management for developers: simply add STaaS user to repo
    * Single SSH key means all tools should authenticate correctly
* Cons
    * Larger exposure: if key is compromised, all repos the STaaS user has access to are accessible
    * Private key is available to Docker, and possibly exploitable by a malicious Dockerfile
    * Need to administer a non-personal account (e.g. maintain 2FA access via dedicated phone, etc)

### C. Only use built artefacts as dependencies

Builds with dependencies that require authentication would be disallowed. The recommended process is then that any private dependencies be built separately and deployed to a common internal registry (e.g. in the case of npm packages, this would be [our own npm registry](https://docs.npmjs.com/misc/registry). Authentication to this registry can then be made available to the build process.

* Pros
    * Better practice for deploying production-ready code dependencies
    * Internal registries less exposed to external access
* Cons
    * Dev/testing/QA phases of CI/CD could become unfeasible for some development scenarios (e.g. if an application and a dependency are being developed in tandem, the requirement to publish the dependency before consuming it could be too time-consuming)
* Unsolved issues
    * Access control to central registries is undefined: would an application be allowed to use any other internally-published packages? If no, we would have to resolve mapping of keys to dependencies (as for scenario A), and any keys could be accessed from a malicious Dockerfile.

## Status of build secrets in Docker

Docker Vault proposed in https://github.com/moby/moby/issues/10310 on January 23, 2015 and closed on Juni 4, 2015 without solution pointing to continue discussion in https://github.com/moby/moby/issues/13490

Azure Draft is discussing to have replacable Docker build engines because the alternatives are getting better (https://github.com/Azure/draft/issues/564), a winner between img, builda, buildkit etc is not know yet though.

A proposed change to docker build to allow more secure --build-args was explicitly shot down here: https://github.com/moby/moby/pull/36443#issuecomment-369845823 because build args SHALL NOT EVER be used for storing any sensitive information and any attempt to improve on that is wrong.

Summary of that issue:

The way one of the docker maintainers do is
  - Clone dependencies and repos OUTSIDE docker build
    - But this breaks the reproducability we want and complicates things a lot
  - Use multi-stage builds
    - Not possible to download all dependencies ahead of time when external dependencies are referenced in for example packages.json (as is the case for Cuillin)

Effort is now on the successor to docker build, buildkit, to provide proper ways of handling secrets during build time.

To explore: would any of these tools handle build secrets better?

  * https://github.com/GoogleContainerTools/kaniko
  * https://github.com/genuinetools/img
  * https://github.com/cyphar/orca-build
  * https://github.com/projectatomic/buildah