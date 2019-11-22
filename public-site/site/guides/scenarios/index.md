---
title: Scenarios and examples
layout: document
parent: ["Guides", "../../guides.html"]
toc: true
---

On this page you will find scenarios describing different app structures.
For each scenario you can find example code for at least one programming language. The code is meant to give you an idea of how your project should look when deploying it to the radix platform. The examples is also a way for you to try out the platform, simply [clone](https://git-scm.com/docs/git-clone) or copy the code to your own repository and follow the instructions on the [Configure an app](../configure-an-app/) guide.

> **If there are no examples for your programming language:** Note that the main difference between all the examples is in the `radixconfig.yaml` and `Dockerfile`s, so you might still find these files and the project structures useful

## Authentication with AD

App which authenticates the user in AD, if logged in read basic user information from AD.

- [Omnia Radix Auth Example](https://github.com/equinor/radix-example-auth)

Example for Omnia Radix showing how to use a OAuth proxy for authentication
- [ Omnia Radix OAuth proxy for authentication](https://github.com/equinor/radix-example-oauth-proxy)


## Other samples

App with ''multiple'' containers. No external dependencies. No back end dependencies. No storage. No secrets. Static/Dynamic web page  

- [App with ''multiple'' containers - React.js](https://github.com/equinor/radix-example-scenario-2-chat)

App with monitoring, Prometheus and Grafana

- [Prometheus metrics app - Node.js](https://github.com/equinor/radix-example-scenario-5-nodejs)  


App ''running linter and unit tests as part of multistage docker build''. Broken tests fail build.

- [Multistage docker build app - Python](https://github.com/equinor/radix-example-scenario-7-python)


