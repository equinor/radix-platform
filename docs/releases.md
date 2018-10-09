# Radix Releases

This is an overview of current and previous Radix releases and deployments.

We are experimenting with an approach with "release channels" which differ in update frequency, service level objectives(SLO) and agreements(SLA) and expected stability.

|    Channel     |                                           Purpose                                                  |    Support    |      SLO      |      SLA      |
|----------------|----------------------------------------------------------------------------------------------------|:-------------:|:-------------:|:-------------:|
| **Production** | Run workloads to be used by end users.                                                             | To-be-defined | To-be-defined | To-be-defined |
| **Weekly**     | Test and development of Radix. Radix users get to experiment with setting up and running apps.     |  Best-effort  |  Best-effort  |      No       |
| **Nightly**    | Rapid test and integration of Radix Platform. Not to be used for workloads.                        |       No      |       No      |      No       |

> _Abbreviations_: 
> **SLO**: Service Level Objectives - The lower and upper bounds of stability and performance we expect to deliver. Typically measured in uptime, % of successfull requests or latency percentiles (95% of requests < 500ms) 
> **SLA:** Service Level Agreements - Responsibility and sanctions if Service Level Objectives are not met.


## Releases

### Production channel

No production clusters yet. Expected towards end of 2018.

### Weekly channel

|           Name         |    Date    | Version |   Status   |                               Release notes                               |            Web console              |
|------------------------|------------|---------|------------|---------------------------------------------------------------------------|-------------------------------------|
| playground-master-42-a | 2018-10-09 | v1.6.0  | Operating  | [Release notes](../release-notes/release-notes-playground-master-42-a.md) | [Web console](https://web-radix-web-console-prod.playground-master-41-a.dev.radix.equinor.com)                 |

### Nightly channel

Not tracked