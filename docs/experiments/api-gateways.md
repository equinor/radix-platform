# API Gateway

**PS** This article is from june 2018.

The API gateway could in the future be the interface between Radix Web Console and backing APIs and services such as Radix API, Kubernetes API, Prometheus, Grafana, etc.

## Purpose

  * Primary: Provide secure access to cluster internal resources (Prometheus, Grafana). Since some endpoints (Prometheus) do not have authentication or authorization built-in we need a point of control where we can enforce access control. This should preferrably be integrated with Azure AD.
  * Primary: Single point of contact for Radix Web Console. Gathering all relevant endpoints (Kubernetes API, Radix API, Prometheus, Grafana) behind one central endpoint de-couples development of frontend and backend/infrastructure and allows faster development and more control.
  * Bonus: We might be able to skip implementation of authentication in Radix API if authentication in the API gateway is working well.
  * Bonus: Depending on the software used we can also enforce rate-limits, log access to and monitor performance and status of the backing APIs relatively easy.
  * Bonus: Provide API gateway with authentication and logging and monitoring as a service to Radix customer applications.


## Comparison =====


|                          | GH Stars  | License      | Pricing                                                      | State            | Builds on      | Auth                               | ACL                        | Rate-limit  | Logging    | Metrics  | Websockets  | Other                                |   |
| ---                         | ---  | ---      | ---                                                      | ---            | ---      | ---                               | ---                        | ---  | ---    | ---  | ---  | ---                                | ---  |
| Kong Community Edition   | 16500     | Open-source  | Free                                                         | Postgres         | Nginx and Lua  | JWT via plugin                     | Yes                        | Yes         | Yes        | Yes      | Yes         | WebUI. K8s Ingress.                  |   |
| Kong Enterprise Edition  | 16500     | Commercial   | Opaque                                                       | Postgres         | Nginx and Lua  | OIDC via plugin                    | Yes                        | Yes         | Yes        | Yes      | Yes         | WebUI. K8s Ingress.                  |   |
| Tyk                      | 3400      | Open-source  | Free for open source. Up to £10000/year for commercial use.  | Redis & MongoDB  | Golang         | JWT and OIDC                       | Yes                        | Yes         | Yes        | Yes      | Yes         | WebUI                                |   |
| Træfik                   | 15800     | Open-source  | Free                                                         | No               | Golang         | No                                 | No                         | No          | Yes        | Yes      | Yes         | WebUI. Auto HTTPS. K8s integration.  |   |
| NGINX                    | 6000      | Open-source  | Free                                                         | No               | C              | Via outdated 3rd party JWT addons  |                            |             |            |          |             |                                      |   |
| NGINX Plus               | 6000      | Commercial   | $3500 /year /instance                                        | No               | C              | Yes, JWT                           | Via static config          | Maybe       | Yes        | No       | Yes         |                                      |   |
| express-gateway          | 980       | Open-source  | Free                                                         | No               | nodejs         | JWT                                | Ish. RBACL on roadmap.     | Yes         | Plaintext  | No       | Roadmap     |                                      |   |
| gravitee.io              | 200       | Open-source  | Free                                                         | No               | Java           | JWT                                | Ish. Policies.             | Yes         | Yes        | Yes      | Unknown     | WebUI.                               |   |
| Ambassador               | 700       | Open-source  | Free                                                         | No               | Envoy          | Can call external service          | Can call external service  | Yes         | No         | No       | Probably    |                                      |   |
| Envoy                    | 5200      | Open-source  | Free                                                         | No               |                | Maybe soon                         | Unknown                    | Yes         | Yes        | No       | Probably    |                                      |   |




### Kong

  * GH Stars: 16.500
  * GH Pulse: 5 PR, 7 issues last 7 days
  * License: Free Community Edition (CE) and Paid Enterprise Edition (EE)
  * Pricing: Completely opaque. Requested quote. (Answer: Kong EE is bundled offer with an annual subscription in the high-five-figures (USD).)

Kong is based on nginx and uses Lua to extend it.

Features:
  * Authentication: JWT plugin available in CE. OIDC plugin available in EE.
  * Access control: ACL plugin available in CE. Can map access from a group of users to a set of Routes.
  * Rate-limiting: Basic in CE. Advanced in EE.
  * Logging: TCP, File, syslog, StatsD, traces to Zipkin
  * Web-sockets:
  * Other: 
    * Correlation ID generator. 
    * FaaS integrations with Azure Functions and AWS Lambda. 
    * Native Kubernetes ingress controller.
    * Has a WebUI for configuration and monitoring.

State stored in: Postgres or Cassandra


### Tyk
  * GH Stars: 3.400
  * GH Pulse: 6 PR, 11 issues last 7 days
  * License: Free for non-commercial use.
  * Pricing: £2000/year for 1 instance. £6000/year for 2 instances. £10000 per year for unlimited instances.
  * Based on: Golang

Features:
  * Authentication: JWT and OIDC.
  * Access control: Via security policies.
  * Rate-limiting: Yes, and quotas.
  * Logging: StatsD, syslog, logstash
  * Web-sockets: Yes
  * Other: 
    * Caching.
    * Can trigger webhook on API call.
    * Has a WebUI for configuration and monitoring.

State stored in: Redis and MongoDB


### Træfik
  * GH Stars: 15.800
  * GH Pulse: 20 PR, 27 issues last 7 days
  * License: Open-source
  * Based on: Golang

A small and fast reverse proxy aimed at exposing internal services that change often and provide logging and monitoring. Does not do anything to control or change the traffic by authentication, access control, rate-limiting or anything else.

Features:
  * Authentication: Nope
  * Access control: Nope
  * Rate-limiting: Nope
  * Logging: JSON, CLF
  * Metrics: Prometheus, Statsd
  * Web-sockets: Yes
  * Other: 
    * Automatic configuraton from Kubernetes. 
    * Automatic HTTPS from Let's Encrypt.
    * Has a WebUI for monitoring.

Pros: 
  * Very small and fast
  * No state to store (it seems)

### NGINX
  * GH Stars: 6.000, but read-only mirror. Development done on a Mercurial server.
  * License: Free open-source and paid NGINX Plus
  * Pricing: Professional $3.500/year per instance. Enterprise support for $5.000/year/instance. Unlimited use available via sales channels.

The de-facto standard web server and reverse proxy. Written in C and extended by Lua scripts.

Features:
  * Authentication: With NGINX Plus and auth_jwt module. Open source addon `lua-resty-jwt` (not updated for 12 months). Open source addon `nginx-jwt` (not updated for 3 years).
  * Access control: Not integrated with auth. Static config per backend/endpoint.
  * Rate-limiting: Maybe via addons.
  * Logging: Syslog
  * Metrics: No
  * Web-sockets: Yes

### express gateway
  * GH Stars: 980
  * GH Pulse: 3 PR, 6 issues last 7 days
  * License: Open-source
  * Based on: nodejs

express gateway looks like the framework for processing HTTP requests and hooking on various middleware for any wanted action, that being observing something about a request or changing a request or response.

Features:
  * Authentication: JWT in core for now. Lots and lots of improvements to security and authentication on roadmap.
  * Access control: Looks like it, via policies written in JS(?). RBACL on roadmap.
  * Rate-limiting: Yes
  * Logging: Plaintext
  * Metrics: Nope
  * Web-sockets: On roadmap

### gravitee.io
  * GH Stars: 200
  * GH Pulse: 6 PR, 0 issues last 7 days
  * License: Open-source
  * Built on: Java

Features:
  * Authentication: JWT
  * Access control: Configured/defined/programmed in routing policies
  * Rate-limiting: Yes
  * Logging: Yes
  * Metrics: Yes
  * Web-sockets: Not mentioned
  * Other: 
    * Has a WebUI for configuration and monitoring.


### Ambassador
  * GH Stars: 700
  * GH Pulse: 15 PR, 12 issues last 7 days
  * License: Open-source

"Ambassador is an open source Kubernetes-native API Gateway built on Envoy, designed for microservices. Ambassador essentially serves as an Envoy ingress controller, but with many more features."

Features:
  * Authentication: Can authenticate every request via call to external service
  * Access control: Can authorize every request via call to external service
  * Rate-limiting: Yes
  * Logging: Doesn't look like it
  * Metrics: Doesn't look like it
  * Web-sockets: Probably
  * Other: 
    * Istio integration

  
### Envoy

  * GH Stars: 5200
  * GH Pulse: 54 PR, 32 issues last 7 days
  * License: Open-source

Features:
  * Authentication: Maybe soon. Open issue: https://github.com/envoyproxy/envoy/issues/2514
  * Access control: Not sure
  * Rate-limiting: Yes
  * Logging: To file, traces to zipkin
  * Metrics: Nope
  * Web-sockets: Probably (HTTP2)
