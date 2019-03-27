---
title: SLA
layout: document
toc: true
---


# Clusters
We are experimenting with an approach with "release channels" which differ in update frequency, service level agreements(SLA) and expected stability.

|    Cluster            |             Purpose                              |      Termination/Upgrade    |   Support    |     
|-----------------------|--------------------------------------------------|:---------------------------:|:------------:|
| **Production**        | Radix production - currenly limited access       | Every ~3 months             | Yes          |   
| **Playground**        | "Open" for test and experimenting with Radix     |                             | Best-effort  |  
| **Weekly**            | Test and development for the Radix team          | 2-3 weeks after creation    | Best-effort  |

# Production 

Procuction with limited access for selected teams and products. Limited access while we learn more about the operations of Radix.

**SLA**
  * **Support channels:** File issue on [radix-platform repo](https://github.com/equinor/radix-platform/issues) or ask on #omnia_radix_support on Slack.
  
  Schedule for DevOps/Support team - Norway default, i.e. 08:00 - 16:00 on Norwegian working days
  
  * **SLA Response time:** As soon as possible, at least Next Business Day (NBD).
  * **On call duty:** No  
  * **SLA Resolution time:** Cannot be guaranteed but for critical issues work on fixing the problem will start immediately and continue within business hours until resolved.
  
  * **SLA Maximum downtime within supported hours: 4 hours downtime per week**
  * **SLA Customer application availability: tbd**
  * **SLA Omnia Radix platform availability: tbd** 
  * **Planned maintenance:** We will try to announce planned maintenance at least 2 business days in advance. Downtime during planned maintenance does not count towards uptime goals.
  
  
ASSOCIATED OPERATIONAL RISKS
- No incident management beyond schedule "Norway - default" - i.e. no support after 16:00 CET/CEST on Norwegian working days.
- Risks for infrastructure downtime despite robust, high availability infrastructure.
- Disaster recovery in experimentation for platform and possibly apps.


# Playground cluster

  * **Support channels:** Ask on #omnia_radix_support on Slack, file issues on [radix-platform repo](https://github.com/equinor/radix-platform/issues)

**Service Level Agreement**
  * **Minimum uptime pr month (or maximum downtime within supported hours):** xxx
  * **Planned maintenance:** Maintenance that will have impact will be announced in advance.

