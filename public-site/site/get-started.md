---
title: Getting started
layout: page
toc: true
---

# What is Radix?

Omnia Radix is a Platform-as-a-Service ("PaaS", if you like buzzwords). It builds, deploys, and monitors applications, automating the boring stuff and letting you focus on your code. Applications run in <abbr title="someone else's computer">the cloud</abbr> as Docker containers, in environments that you define.

# Requirements

There aren't many requirements: Radix runs applications written in Python, Java, .NET, JavaScript, or [LOLCODE](https://en.wikipedia.org/wiki/LOLCODE) equally well. If it can be built and deployed as Docker containers you are nearly ready. If not, it's not hard to "dockerise" most applications: we have guides [TODO: link] and [human help]({% link community.md %}) on hand.

An in-depth understanding of Docker is not a requirement, but it helps to be familiar with the concepts of containers and images. There are many beginner tutorials online, here's one of the most straightforward: [Getting Started with Docker](https://scotch.io/tutorials/getting-started-with-docker).

It is also expected that you have a [basic understanding of Git](http://rogerdudler.github.io/git-guide/) (branching, merging) and some networking (ports, domain names).

# Setting up

What you need to get your application in Radix:

- A GitHub repository for your code (only GitHub is supported at the moment)
- A `radixconfig.yaml` file that defines the running environments. This must be in the root directory of your repository.
- At least one `Dockerfile` that builds and serves your application. You can have several of these files: one per component, in separate directories (e.g. a "front-end" component and a "back-end" component).

We will go over these points below.

## Your repository

There are only a couple of rules in place.

First, all of your application's **components must be in the same repository**. They will be built and deployed together. There is currently no concept of a multi-repository application.

Second, **each environment is mapped to a branch**. This means that, for instance, your `dev` environment might be built and deployed from `master`, while a `prod` environment can be built and deployed from the `production` branch.

A single branch can be mapped to multiple environments. You can also use any branching strategy: Radix won't do anything with branches unless they are mapped to an environment. But you will want a workflow that includes changes being merged to your environment-mapped branches.

## The `radixconfig.yaml` file

This is the Radix configuration file, which specifies how your application is built and deployed. It must be placed in the root of your repository.

> Radix only reads `radixconfig.yaml` from the `master` branch. Changes to this file in other branches (even branches that are mapped to environments) are ignored.

If you are unfamiliar with YAML, it is fine to write the configuration as JSON instead — just keep the same filename.

Here is a simple example:

```yaml
apiVersion: radix.equinor.com/v1
kind: RadixApplication
metadata:
  name: my-cool-app
spec:
  environments:
    - name: dev
    - name: prod
  components:
    - name: main
      src: "."
      public: true
      ports:
       - name: http
         port: 80
```

The same, but as JSON:

```json
{
   "apiVersion": "radix.equinor.com/v1",
   "kind": "RadixApplication",
   "metadata": { "name": "my-cool-app" },
   "spec": {
      "environments": [
         { "name": "dev" },
         { "name": "prod" }
      ],
      "components": [
         {
            "name": "main",
            "src": ".",
            "public": true,
            "ports": [
               { "name": "http", "port": 80 }
            ]
         }
      ]
   }
}
```

The syntax of this file is explained in the [full documentation](https://github.com/Statoil/radix-operator/blob/master/docs/radixconfig.md).

## A `Dockerfile` per component

Each component in Radix is built separately as a Docker image. The images for all components are deployed as containers running in a common environment. To do this, Radix requires a `Dockerfile` for each component — and a way to find those files.

If you organise your repository with this structure, for instance:

```
/
├─ fe/
│  ├─ Dockerfile
│  └─ *frontend component code*
│
├─ be/
│  ├─ Dockerfile
│  └─ *backend component code*
│
└─ radixconfig.yaml
```

In `radixconfig.yaml` you can define the following components:

```yaml
  components:
    - name: frontend
      src: "./fe"
    - name: backend
      src: "./be"
```

Note the `src` property for each component: this is the path to the directory containing the `Dockerfile` for that component. Radix will try to build the image within that directory.

The `Dockerfile` should define a **multi-stage build** in order to speed up the builds and make the resulting image as small as possible. Here is an example for a simple Node.js single-page application:

```docker
FROM node:carbon-alpine as builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:1.14-alpine
WORKDIR /app
COPY --from=builder /app/build /app
COPY nginx.conf /etc/nginx/conf.d/default.conf
```

Note how the first section uses a larger image (`carbon-alpine`) with all dependencies to build the component, and then just the built files are taken into a small image (`nginx`) to serve them.

There are other examples of how to create an efficient `Dockerfile` in [the documentation]({% link documentation.md %}#dockerfile-examples-and-best-practice).

# Register your application

You are now ready to register your application using the [Radix Web Console](https://web-radix-web-console-prod.playground-master-42.dev.radix.equinor.com). Use the "Create an app" link on the top right and follow the instructions there.
