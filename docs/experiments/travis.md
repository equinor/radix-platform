## Travis CI

[Travis CI](https://travis-ci.org/) provides a hosted service for building applications hosted on GitHub. It is free 
for public (open source) projects, and works in a quite straight forward manner.

After we login to the Travis CI portal, we can activate a public project on GitHub to be built by Travis CI whenever a 
commit is pushed to a selected branch.

A configuration file `.travis.yml` should be added to the root directory of a project that describes the build 
environment and steps.

Experiments:

  * A simple Spring Boot hello world Web app is available on https://github.com/thezultimate/hello-spring-boot for testing purpose. When a new commit is pushed to the master branch on GitHub, the build pipeline will be executed by Travis CI, which builds, runs a unit test, creates a Docker image, and pushes to a Docker registry Docker Hub.

## Standalone Docker for Travis CI

Travis CI is an open source project (https://github.com/travis-ci), but it is not easy to install and set it up 
ourself. If we need to have our own Travis CI build server, the following articles might be useful.

  * https://docs.travis-ci.com/user/common-build-problems/#Troubleshooting-Locally-in-a-Docker-Image
  * https://medium.com/google-developers/how-to-run-travisci-locally-on-docker-822fc6b2db2e