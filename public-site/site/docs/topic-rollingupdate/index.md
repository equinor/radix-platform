---
title: Rolling updates
layout: document
parent: ["Docs", "../../docs.html"]
toc: true
---

Radix aims to support zero downtime application re-deployment by utilising Kubernetes' [rolling update](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/) and [readiness probe](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/) features.

## Rolling updates

Rolling updates allow applications to be incrementally updated by specifying the following two parameters.

- Maximum number of pods that can be unavailable during an application update (currently set by Radix to 25% of the number of requested replicas).
- Maximum number of new pods that can be created during an application update (currently set by Radix to 25% of the number of requested replicas).

By using rolling updates, Radix makes sure that old pods are not deleted before new pods are created and in ready state.

## Readiness probe

Rolling updates ensure that the application is always available at pod level. However, as soon as new pods are in ready state, request traffic will be automatically re-routed to the new pods and the old pods are deleted. An issue that typically arises in this scenario is that the actual applications that run inside the containers in the new pods are not ready to receive traffic yet (e.g. still being bootstrapped), and thus, causing a short downtime.

Radix uses readiness probe to minimize this downtime as close to zero as possible, where TCP socket is utilized. Kubernetes will attempt to open a TCP socket to the application container on the port specified in `radixconfig.yaml` file according to the following two parameters.

- Initial delay seconds where Kubernetes will wait before performing the first probe after the container has started (currently set by Radix to 5 seconds).
- Period seconds interval where Kubernetes will perform the probes after the initial probe (currently set by Radix to 10 seconds).

HTTP probe to the application is planned to be implemented in the future to ensure absolute zero downtime. However, this will require Radix users to provide an endpoint in their applications where Kubernetes will perform the probe.