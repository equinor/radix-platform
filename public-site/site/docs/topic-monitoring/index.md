---
title: Monitoring concepts
layout: document
parent: ['Docs', '../../docs.html']
toc: true
---

# Background

## Purpose

There are several benefits of doing monitoring:

- Make it easier to locate and fix problems in the event of an outage (reduced MTTR)
- Identify trends that could lead to an outage and fix them proactively (increased MTBF)
- Better understanding of the resource usage of an application, which makes it possible to scale resources more appropriately and avoid resource waste.

## Events vs metrics

Monitoring data can be roughly split into two categories, events and metrics.

Events are typically logs of a single (discrete) event with some information embedded in the event. One HTTP request would be an event with information about the request latency, status, size, user-agent, etc. Visualizing events typically involves aggregating some specific portion of the event data and maybe also cross-reference it with other fields in the event for correlations.

Metrics (also called time-series) is a measurement of a continuous state of something. Memory usage of a process is not something that happens, but is something that is, and can be measured at points in time. For metrics the challenge is to select the interval to measure things. Measure to often and it becomes costly to gather, process and store the data. Measure to seldom and risk not having enough data when trying to identify problems or bottlenecks.

## Proactive/Reactive

When talking about system stability we have two terms, MTBF and MTTR.

MTBF is Mean time between failures. This is how often a system is non-operational (experiencing unexpected behavior/crashes/unstable). We can increase MTBF by being **pro-active**. We can set thresholds for our metrics so that we get notified when something is out of balance, but before the usability of the system is affected. For example memory usage is increasing much faster than usual. Or memory usage is above X%.

MTTR is Mean time to recovery. This is how much time it takes to get a non-operational system back to normal again. This is the reactive phase. We can decrease MTTR by having a good understanding of how the system is behaving when it works, so that we can easier spot differences in behavior when it's not working like it should. If we have detailed metrics going back in time we can correlate and see for example that CPU usage spiked to 100% just before the service started behaving weird.

## Keywords/Glossary

- TSDB - Time-series database - A special type of database that is designed to ingest large amounts of metrics and make different kinds of queries, aggregated, histograms, etc.

# Methodologies

## USE Method

Brendan Gregg proposed in 2012 a [methodology for analyzing the performance of any system](http://www.brendangregg.com/usemethod.html).

USE means:

- Utilization - the average time that the resource was busy servicing work
- Saturation - the degree to which the resource has extra work which it can't service, often queued
- Errors - the count of error events

Utilization is usually the easiest to measure, we can easily measure CPU, memory, network and storage/IO utilization in %. Saturation in disk/IO can for example be to measure CPU IOWAIT or linux load averages. Swapping can be a sign of saturation in memory. Dropped packets can be a sign of saturation on the network interface. Errors are usually not available as a metric, but shows up in logs as unstructured text.

## RED Method

Based on principles outlined in the [Golden Signals from Google](https://landing.google.com/sre/book/chapters/monitoring-distributed-systems.html) comes the RED method.

RED focuses on the request/transactions/operations that a system/component executes.

RED means:

- Rate - Requests per second
- Errors - Failed requests per second
- Duration - The latency for a request to be completed

Since RED focuses on a request it's either calculated from a log of events/requests or aggregated into min/average/max before being saved as a continous metric. This makes it more challenging to set up the monitoring infrastructure for, but in a HTTP API based system it's easy to measure since the rate, latency and status of a HTTP request is universal and can be measured at several different places.

## Conclusion

USE focuses on causes and are typically internal and we need to be inside the system to measure and observe these metrics.

RED focuses on symptoms and can typically be observed externally from the system itself.
