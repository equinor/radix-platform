---
title: Scaling, limiting, and metering in K8s
layout: document
toc: true
---

First of we need to have a clear distiction between scaling applications on top of Kubernetes and the scaling of the underlying Kubernetes cluster itself. The concepts are similar for both but the processes and possibilities completely separate.

## Radix Platform Customer Applications

### Vertical scaling

Vertical scaling is increasing or decreasing the available resources to an individual running application without creating more instances of the application.

Traditionally application developers have not spent much time on understanding and optimizing the resource usage of their applications. When working locally and deploying to a server that has already been bought there is not that much to gain. The application either works or not and you consume all the available resources on the system if needed.

This way of thinking does not translate well into a cloud environment. Without any incentive to understand and choose the correct resource allocation many will default to ask for, and use as much resources as needed, however much that might be. This leads to the "noisy neighboor" problem where a few badly behaving applications can cause problems for other applications hosted on the same nodes. And if the application owners are not accountable for the running cost of their applications they might as well play safe and request many times more resources than they actually need, significantly increasing the cost for the organization as a whole.

To help with these problems we can use limits, requests (reservations) and metering

#### Limits

Kubernetes has the concept of resource limits for CPU and memory. This limits the amount of CPU and/or memory an application (Pod) or collection of applications (Namespace) can consume. A Pod is generally never able to consume more CPU and memory than the configured limit for it.

#### Requests

Kubernetes also has a concept of resource requests for CPU and memory. This guarantees that a Pod will have a certain amount of resources available to it.

If a Pod has a memory limit of 8GB and memory request of 2GB it can consume for example 5GB of memory for a while if there is available memory on the node. However, if new Pods are placed on the node, the Pod consuming 5GB of memory might be killed to free up memory to give to other Pods with their memory requests. After being killed the Pod will be automatically restarted, but there is now less extra memory to consume above it's requested amount.

**State as of november 2018**: Setting default upper limits and requests for an application is very difficult since for example a nginx web server might perform very well with 30-50MB of memory and 1/4 of a CPU core. A big Java application on the other hand might consume 4-8+ GB of memory and max out many CPU cores.

Ideally a new application should be placed in a sandbox, for example on a dedicated node with plenty of resources. It can run in the sandbox for a few days and either we or the customer can set some sensible requests and limits based on the observed behaviour.

Product owner really wants some hard default limits on resources for all applications. We propose defining 2-3 Pod sizes that can be choosen when creating a new application. A user can always override and set a specific CPU and memory limit, but for new or inexperienced users and applications we lack experience with it might be feasable to start with pre-defined limits.

Pre-defined Pod sizes:
 - **small** - 0.5 vCPU - 1GB RAM - For a small webapplication such as NodeJS, Django
 - **medium** - 2 vCPU - 4GB RAM - For a larger application doing more processing
 - **huge** - 16 vCPU - 64GB RAM - For an application with unknown resource footprint. For example Java-based applications or things doing simulations etc.

> Radix offers monitoring of resource usage so an application can initially be run with **huge** resources and then after some days of monitoring more appropriate resource limits can be set.

For this setup the node size for a production cluster should be D16v3 with 16vCPU and 64GB RAM at $625/month/node before any Equinor discounts.

**Future**: A Verical Pod Autoscaler (VPA) is currently in alpha (https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler). It observes the actual resource usage of a Pod over the past few minutes and can adjust the requests and limits for the Pod dynamically.

#### Metering

Kubernetes does NOT have a concept of metering. Metering is measuring resource usage over time with the goal of making the user aware that using resoures have a cost. Granular and frequent metering is the foundating of the modern cloud. You can pay per-second, per-MB, per-request of what you consume. This makes operating costs for good and efficient software low and big and bloated software high.

Metering can either be done on actual resource usage og reserved resources. I think metering on reserved resources forces users to set fair resource reservations.

As a MVP we can start by looking at historical metrics already collected about requested CPU and memory and calculate the total of CPU-hours and memory-GB-hours an application have used per week or month.

### Horizontal scaling

Horizontal scaling is increasing or decreasing the number of instances of an application/component/process (Pod) that is available to run a workload.

Horizontal scaling does not only provide more instances to increase the total capacity of the application but it can also provide resiliency since one or more instances can disappear without affecting the application (if set up correctly).

> **PS** Note that not all applications can be scaled horizontally. An application has to be architected in a way that plays well with horizontal scaling.

An application can be manually scaled up by adjusting the number of `replicas` in the Deployment. 

Kubernetes also provides a Horizontal Pod Autoscaler, HPA, (https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) that can increase or decrease the number of `replicas` in a Deployment based on CPU, memory or custom application metrics (for example request latency or work queue length)

My recommendation is that new applications get `replicas: 1` by default and that the user can optionally set a desired number of replicas or turn on HPA and set their desired CPU/memory/custom metric thresholds.

> **PS** Having any kind of autoscaling also requires us to pay closer attention to metrics to avoid situations where the system itself scales up exponentially without control potentially becoming very expensive very quickly.

## Radix Platform Kubernetes

This is about scaling the underlying Kubernetes cluster.

### Horizontal

Kubernetes ships with a Cluster Autoscaler, CA, (https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler), that can request more nodes from the cloud provider if needed. Provisioning new nodes is based on the number of pending Pods in the cluster. If there are Pods that are stuck in `pending` because of insufficient resoures in the cluster, CA can request new nodes be added to the cluster from the cloud provider.

Cluster Autoscaler and Azure AKS integration is currently in Preview (https://docs.microsoft.com/en-us/azure/aks/autoscaler).

### Vertical

It's not possible to vertically scale an AKS cluster (increase the node VM size). It will be possible to add larger nodes when AKS adds support for node-pools (https://github.com/Azure/AKS/issues/287). Support for node-pools has been delayed from Q3 2018 to currently Q1 2019. There are however no existing tool that does automatic vertical scaling on a cluster level.

## Summary and MVP suggestions

### Apps

#### Metering

No tooling available.
As a MVP we can start by looking at historical metrics already collected about requested CPU and memory and calculate the total of CPU-hours and memory-GB-hours an application have used per week or month.

#### Horizontal scaling

Set `replicas: 1` by default and let the app owner be able to change this when they know that their app will play well with horizontal scaling.
A better suggestion is to let them enable HPA if they are able to provide desired CPU/memory/custom metric thresholds for the app.

First of we need to have a clear distiction between scaling applications on top of Kubernetes and the scaling of the underlying Kubernetes cluster itself. The concepts are similar for both but the processes and possibilities completely separate.

### Cluster

Waiting for
- [Cluster Autoscaler to be integrated in AKS](https://docs.microsoft.com/en-us/azure/aks/autoscaler) (still in preview)
- The availability of node pools in Q1 2019


