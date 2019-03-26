---
title: SLA
layout: document
toc: true
---


# Clusters
We are experimenting with an approach with "release channels" which differ in update frequency, service level agreements(SLA) and expected stability.

|    Cluster            |                       Purpose                              |      Termination     |   Support    |     
|-----------------------|------------------------------------------------------------|:--------------------:|:------------:|
| **Production**        | Run workloads to be used by end users.  To be announced in 2019. |               |              |      
| **Limited production**|                                                            | Every ~3 months      | Best effort |    
| **Weekly**     | Test and development for the Radix team                           | 2-3 weeks after creation | Best-effort |  
| **Playground**  | Test and development of Radix.                                   |                 | Best-effort  |  

# Production 

> **No production clusters yet. Expected early 2019.**

# Limited production 

Before going into production we start with a Limited production to gather experience in close collaboration with a select few pilot teams and guide us towards going to full production.

**Support**
  * **Support channels:** File issue on [radix-platform repo](https://github.com/equinor/radix-platform/issues) or ask on #omnia_radix_support on Slack.
  
  Schedule for DevOps/Support team - Norway default, i.e. 08:00 - 16:00 on Norwegian working days
  
  * **SLA Response time:** As soon as possible, at least Next Business Day (NBD).
  * **On call duty:** No  
  * **Resolution time:** Cannot be guaranteed but for critical issues work on fixing the problem will start immediately and continue within business hours until resolved.
  
  * **Minimum uptime pr month or maximum downtime within supported hours:**
  * **Customer application availability:**
  * **Omnia Radix platform availability:** 
  * **Planned maintenance:** We will try to announce planned maintenance at least 2 business days in advance. Downtime during planned maintenance does not count towards uptime goals.
  
  
ASSOCIATED OPERATIONAL RISKS
- No incident management beyond schedule "Norway - default" - i.e. no support after 16:00 CET/CEST on Norwegian working days.
- Risks for infrastructure downtime despite robust, high availability infrastructure.
- Disaster recovery not established.


# Playground cluster

**Support**
  * **Response time:** Issues filed on [radix-platform repo](https://github.com/equinor/radix-platform/issues) will be answered within Next Business Day (NBD).


**Service Level Objective**
  * 90% uptime per month.
  
**Service Level Agreement**
  * **Recourse:** None
  * **Planned maintenance:** Maintenance may or may not be announced in advance.

