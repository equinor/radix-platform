---
title: Releases
layout: document
toc: true
---

This is an overview of current and previous Radix releases and deployments.

# Channels
We are experimenting with an approach with "release channels" which differ in update frequency, service level objectives(SLO) and agreements(SLA) and expected stability.

|    Channel     |                                           Purpose                                                  |        Termination [1]   |   Support    |     SLO [2]   |    SLA [3]    |
|----------------|----------------------------------------------------------------------------------------------------|:------------------------:|:------------:|:-------------:|:-------------:|
| **Production** | Run workloads to be used by end users.                                                             |     Every ~3 months      |     NBD      |      99%      |      No       |
| **Weekly**     | Test and development of Radix. Radix users get to experiment with setting up and running apps.     | 2-3 weeks after creation | Best-effort  |   98% / 97%   |      No       |
| **Nightly**    | (**PS: Not used**) Rapid test and integration of Radix Platform. Not to be used for workloads.     |           Daily          |      No      |       No      |      No       |

> _Legend_:
> [1] **Termination**: The lifetime before a cluster will be terminated. There will always be a newer cluster available before an old one is terminated and we will ensure application migrations to a new cluster is as smooth as possible. The reason for limiting the lifetime of a cluster is to limit the accumulation of changes to cluster state that is not documented and reproducible which can make later integrations and disaster recovery unnecessarily difficult.
> 
> _Abbreviations_: 
> [2] **SLO**: Service Level Objectives - The lower and upper bounds of stability and performance we expect to deliver. Typically measured in uptime, % of successfull requests or latency percentiles (95% of requests < 500ms) 
> [3] **SLA:** Service Level Agreements - Responsibility and sanctions if Service Level Objectives are not met.

# Production channel

> **No production clusters yet. Expected towards end of 2018.**

**Support**
  * **Response time:** Issues filed on [radix-platform repo](https://github.com/statoil/radix-platform/issues) will be answered within Next Business Day (NBD).
  * **Resolution time:** Cannot be guaranteed but for critical issues work on fixing the problem will start immediately and continue within business hours until resolved.

**Service Level Objective**
  * **Customer application availability:** 99% uptime per month. This is how much of the time your application is available to end users.
  * **Omnia Radix platform availability:** 99% uptime per month. This is how much of the time Omnia Radix is available to do builds, change settings of applications etc. Some Omnia Radix components can be offline for periods without affecting the running applications (control-plane vs data-plane).

> 99% uptime equals approximately 1 working day (7,5 hours) of unplanned downtime per month.

**Service Level Agreement**
  * **Recourse:** For the time being, service level objectives are not guaranteed and breaches does not trigger any compensation or responsibility.
  * **Planned maintenance:** Planned maintenance will be announced 2 business days in advance. Downtime during planned maintenance does not count towards uptime goals.

# Weekly channel

**Support**
  * **Response time:** Issues filed on [radix-platform repo](https://github.com/statoil/radix-platform/issues) will be answered within Next Business Day (NBD).
  * **Resolution time:** Cannot be guaranteed but for critical issues work on fixing the problem will start as soon as possible and continue within business hours until resolved.

**Service Level Objective**
  * **Customer application availability:** 98% uptime per month. This is how much of the time your application is available to end users.
  * **Omnia Radix platform availability:** 97% uptime per month. This is how much of the time Omnia Radix is available to do builds, change settings of applications etc. Some Omnia Radix components can be offline for periods without affecting the running applications (control-plane vs data-plane).

> 98% uptime equals approximately 2 working days (15 hours) and 97% uptime equals approx 3 working days (22,5 hours) per month of unplanned downtime.

**Service Level Agreement**
  * **Recourse:** None
  * **Planned maintenance:** Maintenance may or may not be announced in advance.


|           Name         |    Date    | Version |   Status   |                               Release notes                               |            Web console              |
|------------------------|------------|---------|------------|---------------------------------------------------------------------------|-------------------------------------|
| playground-master-47   | 2018-11-19 |         | Operating  | [Release notes]({% link release-notes/release-notes-playground-master-47.md %}) | [Web console](https://web-radix-web-console-prod.playground-master-47.dev.radix.equinor.com)   |
| playground-master-46   | 2018-11-15 |         | Aborted    | Aborted due to problems. Superseded by playground-master-47               |     |
| playground-master-45   | 2018-11-06 |   | Operating  | [Release notes]({% link release-notes/release-notes-playground-master-45.md %}) | [Web console](https://web-radix-web-console-prod.playground-master-45.dev.radix.equinor.com)   |
| playground-master-44   | 2018-10-29 |   | Operating  | [Release notes]({% link release-notes/release-notes-playground-master-44.md %}) | [Web console](https://web-radix-web-console-prod.playground-master-44.dev.radix.equinor.com)   |
| playground-master-43   | 2018-10-25 |   | Operating  | [Release notes]({% link release-notes/release-notes-playground-master-43.md %}) | [Web console](https://web-radix-web-console-prod.playground-master-43.dev.radix.equinor.com)   |
| playground-master-42   | 2018-10-16 |   | Operating  | [Release notes]({% link release-notes/release-notes-playground-master-42.md %}) | [Web console](https://web-radix-web-console-prod.playground-master-42.dev.radix.equinor.com)   |
| playground-master-42-a | 2018-10-09 | v1.6.0  | Operating  | [Release notes]({% link release-notes/release-notes-playground-master-42-a.md %}) | [Web console](https://web-radix-web-console-prod.playground-master-41-a.dev.radix.equinor.com)                 |


# Nightly channel

Not active
