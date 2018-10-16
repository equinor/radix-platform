---
title: Dockerfile for Java (Maven)
layout: page
parent: ['Documentation', '../documentation.html']
toc: true
---

A Dockerfile for packaging a Java application using the multi-stage build pattern.

# Base image

Choice of base image can have a big impact on how easy it is to build, deploy and operate the final Docker image and container.

| Name                    | Size  | Notes                                                |
| ----------------------- |-------| -----------------------------------------------------|
| openjdk:10-jdk          | 883MB | Default OpenJDK based on Debian                      |
| openjdk:10-jdk-slim     | 588MB | Smaller OpenJDK based on Debian-slim                 |
| openjdk:10-jre-slim     | 286MB | JRE based on Debian-slim                             |
| maven:3.5.3-jdk-10      | 893MB | Default OpenJDK including maven based on Debian      |
| maven:3.5.3-jdk-10-slim | 607MB | Smaller OpenJDK including maven based on Debian-slim |

> The smallest Docker images are almost always based on the alpine-linux distribution/base-image. But openjdk 9 and 10 are not available on alpine.

This assumes the `Dockerfile` is in the same folder as the rest of the source-code.

```docker
FROM maven:3.5.3-jdk-10-slim AS build

# We start by copying in the pom-file and download dependencies.
# Unless pom.xml changes and dependencies are added or removed, Docker
# will use a cached image layer and not run mvn dependency:resolve
# unless it's actually necessary. This reduces the image build
# time by 80% for subsequent builds in our tests.
COPY pom.xml /src/pom.xml
WORKDIR /src/
RUN mvn dependency:resolve

# Copy all of the source and compile it, test it and package it
COPY . /src/
RUN mvn package

# Start from scratch with a slim jre image
FROM openjdk:10-jre-slim

# Copy in the build files from the last stage
COPY --from=build /src/target /app

ENTRYPOINT ["/usr/bin/java"]

# The actual jar file to execute when the image is run.
# TODO: Find a way to dynamically detect the correct file.
CMD ["-jar", "/app/gs-rest-service-0.1.0.jar"]

# Information on the port that the service exposes
# and that should be exposed outside Docker
EXPOSE 8080
```

# Building

Run `docker build -t spring-test:0.1.0 .` Where `spring-test` is the application/image name and `0.1.0` is a version label that you choose.

# Running

Run `docker run -p8080:8080 spring-test:0.1.0`. This will open port 8080 on your machine to 8080 inside the Docker container and the application is available on http://localhost:8080/greeting (in the case of this Hello World app).

# Working interactively

Assuming your source code is in d:/data-disk-enc/statoil you can run the maven-jdk Docker container and start a bash script inside it:

```bash
docker run -v d:/data-disk-enc/statoil:/src -it maven:3.5.3-jdk-10-slim bash
```

The source code is available inside `/src` in the container. The changes you make inside the container are also reflected outside.

You can then run commands etc to see which series of commands are needed to create a successful `Dockerfile`.

# Misc

To run a docker build in PowerShell and measure the time it takes:

```
Measure-Command {docker build -t spring-test:latest . | Out-Default}
```

# Issues

Parallel downloads of POM dependencies is slow since it's not done in parallel, however it might be [added "soon"](https://issues.apache.org/jira/browse/MRESOLVER-7).
