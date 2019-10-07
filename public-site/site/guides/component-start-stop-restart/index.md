---
title: Component start/stop/restart
layout: document
parent: ['Guides', '../../guides.html']
toc: true
---

# Overview

It is possible to manually restart or stop-start a running component using the Radix web console, when special circumstances requires it (i.e. after having updated a secret), even though the recommended approach is to use the Radix config.

![Component-stop-start-restart](Component-stop-start-restart.png)

# Stopping

*Stopping* the component will set the replica to 0 for the *active deployment*. Note that if you make a new deployment to the environment, by pushing a change to the branch mapped to the environment, and the replica in the Radix config is not set to 0 for the component, it will restart.

# Starting

*Starting* the component will set the replica to the replicas set in the Radix config for the *active deployment*.

# Restarting

*Restarting* the component will make a rolling restart of the *active deployment*. That means that the application will be responsive during the enire restart, just as with [rolling updates](../../docs/topic-rollingupdate/).