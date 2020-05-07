---
title: Security
layout: document
parent: ['Docs', '../../docs.html']
toc: true
---

# Role Based Access Control

Membership in the 'Radix Platform User' AD group grants access to

- Radix Web Console
- Grafana Dashboard (Monitoring)

Only members of the AD group provided during application registration, will be able to see the application listed in the Radix web console. Same AD group also controls who will be able to change the configuration of the application in the Radix web console. 

If no AD group is provided during the registration the application will be available to all Radix users (members of the 'Radix Platform Users' AD group).

# Authentication

It is important to understand that **application authentication is not handled by Radix**. The application endpoints will be public. Each team managing an application hosted on Radix is responsible for authenticating their users.

For an example of in-app authentication using AD have a look at [Radix Authentication Example](https://github.com/equinor/radix-example-auth).
