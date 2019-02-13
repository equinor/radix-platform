---
title: Docker & containers
layout: document
parent: ["Docs", "../../docs.html"]
toc: true
---

For a general understanding of what Docker and Container is, have a look at [What is a Container](https://www.docker.com/resources/what-container) or a more in-depth presentation from th Stavanger [playground](https://github.com/equinor/playground-stavanger/tree/master/docker-basic).

[Katacoda](https://www.katacoda.com/) offers free courses where you can work with Docker directly in the browser, without having to install it locally. Other resources could be the official [Docker documentation](https://docs.docker.com/).

# Best-practice `Dockerfile`

The official Docker documentation has a set of [best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/) when it comes to creating `Dockerfile`s. This is often related to optimizing build, push and pull speed and creating small and secure images.

## Limit image size

Many of the best practices are connected to creating small images either through using the "correct" BASE image or through Multistage builds.

Small images will be faster to build, push and pull then bigger images. It will have less frameworks dependencies, and therefore smaller risk of security vulnerabilities and bugs. Google cloud platform have a great video on why and how to create small images - [link](https://www.youtube.com/watch?v=wGz_cbtCiEA&list=PLIivdWyY5sqL3xfXz5xJvwzFW_tlQB_GB&index=2), or you can check the [official doc](https://docs.docker.com/develop/develop-images/multistage-build/).

Try to find a guide for the technology stack you work on, to optimize your container further.

## Layers

Docker build speed can be reduced by understanding caching of layers. In short, each line in the Dockerfile can be seen as a layer for the finished image. Docker caches these layers and, if there are no changes, can reuse the cached version when building several times. See [digging-into-docker-layers](https://medium.com/@jessgreb01/digging-into-docker-layers-c22f948ed612) for more information.

## Security

There are many great articles on securing docker images. See [link](https://www.wintellect.com/security-best-practices-for-docker-images/) for one list.

# Radix specific

## Testing

Automatic testing of an application can be done as a build stage inside the container. This will then be run as one of the steps when radix build the image. The [`Dockerfile`](https://github.com/equinor/radix-example-scenario-docker-multistage-with-test/blob/master/Dockerfile) used in the Radix workhops provides a good example.
