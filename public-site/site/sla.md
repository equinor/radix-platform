---
title: Releases
layout: document
toc: true
---


# Clusters
We are experimenting with an approach with "release channels" which differ in update frequency, service level agreements(SLA) and expected stability.

|    Channel     |                                           Purpose                                                  |        Termination [1]   |   Support    |     SLA [2]   |    
|----------------|----------------------------------------------------------------------------------------------------|:------------------------:|:------------:|:-------------:|
| **Production** | Run workloads to be used by end users.  To be announced early 2019.                                |                          |              |               |     
| **Limited production** | Radix users set up dev and test environments and get experience with the platform.         |     Every ~3 months      |     NBD      |   96% / 96%   |   
| **Weekly**     | Test and development of Radix.                                                                     | 2-3 weeks after creation | Best-effort  |   90% / 90%   |  
| **Playground**     | Test and development of Radix.                                                                     | 2-3 weeks after creation | Best-effort  |   90% / 90%   |  

# Production 

> **No production clusters yet. Expected early 2019.**

# Limited production 

Before going into production we start with a Limited production to gather experience in close collaboration with a select few pilot teams and guide us towards going to full production.

**Support**
  * **Support channels:** File issue on [radix-platform repo](https://github.com/equinor/radix-platform/issues) or ask on #omnia_radix_support on Slack.
  * **Response time:** As soon as possible, at least Next Business Day (NBD).
  * **Resolution time:** Cannot be guaranteed but for critical issues work on fixing the problem will start immediately and continue within business hours until resolved.

**Service Level Objective**
  * **Customer application availability:** 96% uptime per month. 1 day downtime per week. This is how much of the time your application is available to end users.
  * **Omnia Radix platform availability:** 96% uptime per month. 1 day downtime per week. This is how much of the time Omnia Radix is available to do builds, change settings of applications etc. Some Omnia Radix components can be offline for periods without affecting the running applications (control-plane vs data-plane).

**Service Level Agreement**
  * **Recourse:** For the time being, service level objectives are not guaranteed and breaches does not trigger any compensation or responsibility.
  * **Planned maintenance:** We will try to announce planned maintenance at least 2 business days in advance. Downtime during planned maintenance does not count towards uptime goals.

# Weekly channel

**Support**
  * **Response time:** Issues filed on [radix-platform repo](https://github.com/equinor/radix-platform/issues) will be answered within Next Business Day (NBD).
  * **Resolution time:** Cannot be guaranteed but for critical issues work on fixing the problem will start as soon as possible and continue within business hours until resolved.

**Service Level Objective**
  * 90% uptime per month.
  
**Service Level Agreement**
  * **Recourse:** None
  * **Planned maintenance:** Maintenance may or may not be announced in advance.

