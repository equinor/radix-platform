---
title: Radix releases
layout: document
toc: true
---

This is an overview of current and previous Radix releases and deployments.

## Releases

### Production channel

No production clusters yet. Expected towards end of 2018.

### Weekly channel

|           Name         |    Date    | Version |   Status   |                               Release notes                               |            Web console              |
|------------------------|------------|---------|------------|---------------------------------------------------------------------------|-------------------------------------|
| playground-master-47   | 2018-11-19 |         | Operating  | [Release notes]({% link release-notes/release-notes-playground-master-47.md %}) | [Web console](https://web-radix-web-console-prod.playground-master-47.dev.radix.equinor.com)   |
| playground-master-46   | 2018-11-15 |         | Aborted    | Aborted due to problems. Superseded by playground-master-47               |     |
| playground-master-45   | 2018-11-06 | a8794f70b2047a5d50d087f0a401ed73fa4ecf10  | Operating  | [Release notes]({% link release-notes/release-notes-playground-master-45.md %}) | [Web console](https://web-radix-web-console-prod.playground-master-45.dev.radix.equinor.com)   |
| playground-master-44   | 2018-10-29 | f7f42a581f455c02b7f52e93a98702d83dd5e99e  | Operating  | [Release notes]({% link release-notes/release-notes-playground-master-44.md %}) | [Web console](https://web-radix-web-console-prod.playground-master-44.dev.radix.equinor.com)   |
| playground-master-43   | 2018-10-25 | c4b7d90ce0d49bc332383b951ffae4f6d2a55bcf  | Operating  | [Release notes]({% link release-notes/release-notes-playground-master-43.md %}) | [Web console](https://web-radix-web-console-prod.playground-master-43.dev.radix.equinor.com)   |
| playground-master-42   | 2018-10-16 | 8eea3123e45643c6348492519f265451fd369a56  | Operating  | [Release notes]({% link release-notes/release-notes-playground-master-42.md %}) | [Web console](https://web-radix-web-console-prod.playground-master-42.dev.radix.equinor.com)   |
| playground-master-42-a | 2018-10-09 | v1.6.0  | Operating  | [Release notes]({% link release-notes/release-notes-playground-master-42-a.md %}) | [Web console](https://web-radix-web-console-prod.playground-master-41-a.dev.radix.equinor.com)                 |


### Nightly channel

Not tracked

## Channels
We are experimenting with an approach with "release channels" which differ in update frequency, service level objectives(SLO) and agreements(SLA) and expected stability.

|    Channel     |                                           Purpose                                                  |        Termination [1]   |   Support    |     SLO [2]   |    SLA [3]    |
|----------------|----------------------------------------------------------------------------------------------------|:------------------------:|:------------:|:-------------:|:-------------:|
| **Production** | Run workloads to be used by end users.                                                             | TBD: Maybe quarterly     |To-be-defined | To-be-defined | To-be-defined |
| **Weekly**     | Test and development of Radix. Radix users get to experiment with setting up and running apps.     | 2-3 weeks after creation | Best-effort  |  Best-effort  |      No       |
| **Nightly**    | Rapid test and integration of Radix Platform. Not to be used for workloads.                        | Daily                    |      No      |       No      |      No       |

> _Legend_:
> [1] **Termination**: The lifetime before a cluster will be terminated. There will always be a newer cluster available before an old one is terminated and we will ensure application migrations to a new cluster is as smooth as possible. The reason for limiting the lifetime of a cluster is to limit the accumulation of changes to cluster state that is not documented and reproducible which can make later integrations and disaster recovery unnecessarily difficult.
> 
> _Abbreviations_: 
> [2] **SLO**: Service Level Objectives - The lower and upper bounds of stability and performance we expect to deliver. Typically measured in uptime, % of successfull requests or latency percentiles (95% of requests < 500ms) 
> [3] **SLA:** Service Level Agreements - Responsibility and sanctions if Service Level Objectives are not met.

Short summary of what weekly channel means:
  - No guarantees of uptime or correctness, but we strive to not break things on purpose. 
  - No guarantees of response or resolution times for questions and support, but we will respond as soon as we are able to.
  - New cluster based on latest code every week. Old clusters will live on for 1-2 weeks after that before being terminated. We will try to make migrations of customer applications to new clusters as seamless as possible.


