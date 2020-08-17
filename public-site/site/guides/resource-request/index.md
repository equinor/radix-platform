---
title: Resource request and limit
layout: document
parent: ["Guides", "../../guides.html"]
toc: true
---

`resources` is used to ensure that each container is allocated enough resources to run as it should. `limits` describes the maximum amount of compute resources allowed. `requests` describes the minimum amount of compute resources requires.

# Why should resources request and limit be set

Settings resources request and limit is important because of several reasons:

- Kubernetes scheduler use the `resources.requests` to decide which node to run a container. It guarantees that each container is allocated `resources.requests`. Without these values, a container is not guaranteed any resources, and will be the first to get stopped if a node is overcommited. 
- Radix use `resources.requests` to distribute infrastructure cost between teams. 
- Radix use `resources.requests` to scale clusters. 
- Horizontal pod autoscaling uses `resources.requests.cpu` as a target for when to scale out to more containers. If a container over time run above 80% of `resources.requests.cpu` it will scale out.
- `resources.limits.memory` will ensure that the container is stopped if there is any memory leakage

If `resources.requests` and `resources.limit` are not provided, Radix will give a container default [values](https://github.com/equinor/radix-operator/blob/master/charts/radix-operator/values.yaml#L24). This will be used for scheduling and cost. In many cases the default `resources` will not fit an application, so adjusted values has to be found.

# How to find resource requests and limits

Monitoring can be used to find how much resources an application use. Radix uses [prometheus](https://prometheus.io/) to gather metrics and [grafana](https://grafana.com/) for visualization. When viewing an application in Radix web console, there is a link to a default dashboard in Radix grafana instance that gives a good starting point for monitoring an app.

![Grafana](link-to-grafana.png)

The default dashboard contains a number of graphs, monitoring different part of an application. For setting `resources` "Container CPU usage" and "Container memory usage" can be used.

CPU and memory are typically impacted by load on an application. If the application is in production, there will already be data that can be used for deciding `resources`. If not, next step involves either running an automated or manual simulation of production environment. It does not need to be very advanced, but it should be possible to see how it behaves under different load. 

Monitoring memory and CPU over time is important, as it can change based on a numerous factors (e.g. new runtime environment, changes to code, increased load, etc). The `resources` set can therefore change during it lifecycle.

Select a single environment and time interval, that represent normal usage for that application. For the `radix-api` examples, production environment and a period of 7 working days has been selected.

## CPU

By clicking a graph, "Container CPU usage", a more detailed view appears. 

![container-cpu](container-cpu.png)

The graph shows how many replicas are running in production and how the CPU usage has been the last 7 days for each replica. Tests are run continuously towards `radix-api`, so there will always be a base CPU usage. This does not need to be the case with other api. 

REWRITE!! CPU is a xxxx resource, meaning that if there are load taking up all CPU it will start throttling applications. It is therefore not crucial to set request CPU for the peeks, but rather have something that will manage for the average load (in business hours). Limit can cope with for the peeks. 

For `radix-api` normal load gives between 100-200ms of CPU time, peaking at around 400ms. Given us the following setup:

```
resources.requests.cpu: 200ms
resources.limits.cpu: 500ms
```

Because of a [limit](https://www.youtube.com/watch?v=eBChCFD9hfs) in how kubernetes / linux and docker throttling is done, it is recommended to set `resources.requests.limits` to a multitude of `1000ms`. Setup for `radix-api` would then be:

```
resources.requests.cpu: 200ms
resources.limits.cpu: 1000ms
```

## Memory

Next go back to the `Default dashboard` and select graph `Container memory usage`. 

![container-memory](container-memory.png)

Memory is a xxx resource. Meaning that if a container requires more memory to run than is available on node, it will be killed. Therefore the `resources.requests.memory` is set to the same as `resources.limits.memory`. The value should be set to above max memory in period of different load (not opening up for memory leakage)

For `radix-api` max memory is around 300MB+, setup will therefore be set to:
```
resources.requests.memory: 400MB
resources.limits.memory: 400MB
```
Ensuring that `400MB` is always allocated to `radix-api`.

# Autoscaling

For modern application development in Kubernetes and in Radix it is preferred to create applications that [scales horizontally rather than vertically](https://www.missioncloud.com/blog/horizontal-vs-vertical-scaling-which-is-right-for-your-app). In horizontal scaling, when there is need for more compute an extra container (pod) is added, but memory and CPU stays fixed. 

![horizontal-pod-autoscaling](horizontal-pod-autoscaling.png)

For Radix this can easily be done through horizontal pod autoscaling in the [radixconfig.yaml](https://www.radix.equinor.com/docs/reference-radix-config/#horizontalscaling). It will scale based on CPU load over time for replicas of a component (higher than 80%). More information can be found at [kubernetes docs](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)


# Cost