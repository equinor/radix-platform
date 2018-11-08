---
title: Getting started
layout: document
toc: true
---

# What is Radix?

Omnia Radix is a Platform-as-a-Service ("PaaS", if you like buzzwords). It builds, deploys, and monitors applications, automating the boring stuff and letting developers focus on code. Applications run in <abbr title="someone else's computer">the cloud</abbr> as Docker containers, in environments that you define.

You can use Radix just to run code, but the main functionality is to integrate with a code repository so that it can continuously build, test, and deploy applications. For instance, Radix can react to a `git push` event, automatically start a new build, and push it to the `test` environment, ready to be tested by users.

Radix also provides monitoring for applications. The are default metrics (e.g. request latency, failure rate), but you can also output custom metrics from your code. Track things that are important for your application: uploaded file size, number of results found, or user preferences. Radix collects and monitors the data.

# Requirements

There aren't many requirements: Radix runs applications written in Python, Java, .NET, JavaScript, or [LOLCODE](https://en.wikipedia.org/wiki/LOLCODE) equally well. If it can be built and deployed as Docker containers, we are nearly ready. If not, it's not hard to "dockerise" most applications: we have [guides]({% link documentation.md %}#dockerfile-examples-and-best-practice) and [human help]({% link community.md %}) on hand.

An in-depth understanding of Docker is not a requirement, but it helps to be familiar with the concepts of containers and images. There are many beginner tutorials online; here's one of the most straightforward: [Getting Started with Docker](https://scotch.io/tutorials/getting-started-with-docker).

It is also expected to have a [basic understanding of Git](http://rogerdudler.github.io/git-guide/) (branching, merging) and some networking (ports, domain names).

# Setting up

In this guide we'll set up an application together. Here's what we need to get our application in Radix:

- A GitHub repository for our code (only GitHub is supported at the moment)
- A `radixconfig.yaml` file that defines the running environments. This must be in the root directory of our repository.
- At least one `Dockerfile` that builds and serves our application. We can have several of these files: one per component, in separate directories (e.g. a "front-end" component and a "back-end" component).

We will go over these points below.

## The repository

All of our **components must be in the same repository**. A component is a piece of code that has its own build and deployment process: for instance a "front end" served by Nginx and a "back end" running on Node.js would be two components. Components are built in parallel from the same repository and deployed together into an environment. There is currently no concept of a multi-repository application.

The way we use branches and tags in our repository depends on what type of workflow we use. You can read more about the choices available in the [workflows]({% link workflows.md %}) page — but let's continue with setting up for now.

## The `radixconfig.yaml` file

In the root of our repository we need a `radixconfig.yaml` file: this is the Radix configuration, which specifies how our application is built and deployed.

> Radix only reads `radixconfig.yaml` from the `master` branch. If the file is changed in other branches, those changes will be ignored.

If you are unfamiliar with YAML, it is fine to write the configuration as JSON instead — just keep the same filename.

Here is a simple example of the file:

```yaml
apiVersion: radix.equinor.com/v1
kind: RadixApplication
metadata:
  name: my-cool-app
spec:
  environments:
    - name: dev
      build:
        from: master
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
   "metadata": { "name": "myapp" },
   "spec": {
      "environments": [
         { "name": "dev", "build": { "from": "master" } },
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

A breakdown of the configuration above:

- Our application is called `myapp`
- There are two environments, `dev` and `prod`, and only one component, `main`
- Commits to the `master` branch will trigger a build and deployment of the application to the `dev` environment. We can use this behaviour to build a [workflow]({% link workflows.md %})
- Radix will look for the `Dockerfile` for the `main` component in the root directory of the repository
- Once `main` is built, it will be exposed on the internet on port 80 on each environment it is deployed to (in `dev`, for instance, it will have a domain name like `main-myapp-dev.CLUSTER_NAME.dev.radix.equinor.com`)

> Once Radix is out of Alpha, the domain names will have the format `COMPONENT-APP-ENVIRONMENT.cluster.prod.radix.equinor.com` instead

The full syntax of `radixconfig.yaml` is explained in the [documentation](https://github.com/Statoil/radix-operator/blob/master/docs/radixconfig.md).

## A `Dockerfile` per component

Each component in Radix is built into a Docker image. Images for all components are deployed as containers running in an environment. To do this, Radix requires a `Dockerfile` for each component.

If we organise our repository with this structure, for instance:

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

In `radixconfig.yaml` we can define the following components:

```yaml
  components:
    - name: frontend
      src: "./fe"
    - name: backend
      src: "./be"
```

Note the `src` property for each component: this is the path to the directory containing the `Dockerfile` for that component. Radix will try to build the image within that directory.

The `Dockerfile` should define a **multi-stage build** in order to speed up the builds and make the resulting image as small as possible. This means that we can decouple the build and deployment concerns. Here is an example for a simple Node.js single-page application:

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

Note how the first section uses a large image (`node`) which has the dependencies needed to build the component. In the second stage, the built files are copied into a small image (`nginx`) to serve them without all the build dependencies.

There are other examples of how to create an efficient `Dockerfile` in [the documentation]({% link documentation.md %}#dockerfile-examples-and-best-practice).

## Registering the application

We are now ready to register our application using the [Radix Web Console](https://console.dev.radix.equinor.com). Follow the instructions there to integrate the GitHub repository with Radix.

Remember that we can always change the `radixconfig.yaml` file and the `Dockerfiles` after registration to change how the application builds and deploys.
