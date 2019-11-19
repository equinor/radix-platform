---
title: Getting started
layout: document
parent: ['Guides', '../../guides.html']
toc: true
---

# What is Radix?

Omnia Radix is a Platform-as-a-Service ("PaaS", if you like buzzwords). It builds, deploys, and monitors applications, automating the boring stuff and letting developers focus on code. Applications run in <abbr title="someone else's computer">the cloud</abbr> as Docker containers, in environments that you define.

You can use Radix just to run code, but the main functionality is to integrate with a code repository so that it can continuously build, test, and deploy applications. For instance, Radix can react to a `git push` event, automatically start a new build, and push it to the `test` environment, ready to be tested by users.

Radix also provides monitoring for applications. There are default metrics (e.g. request latency, failure rate), but you can also output custom metrics from your code. Track things that are important for your application: uploaded file size, number of results found, or user preferences. Radix collects and monitors the data.

> To help improve Radix, request access to the GitHub [Omnia Radix Readers](https://github.com/orgs/equinor/teams/omnia-radix-readers/members) team — this gives you access to poke around in our repositories. We track **issues and feature requests** in the [radix-platform](https://github.com/equinor/radix-platform/issues) repo. Please log those! 🙂

# Requirements

There aren't many requirements: Radix runs applications written in Python, Java, .NET, JavaScript, or [LOLCODE](https://en.wikipedia.org/wiki/LOLCODE) equally well. If it can be built and deployed as Docker containers, we are nearly ready. If not, it's not hard to "dockerise" most applications.

An in-depth understanding of Docker is not a requirement, but it helps to be familiar with the concepts of containers and images. There are many beginner tutorials online; here's one of the most straightforward: [Getting Started with Docker](https://scotch.io/tutorials/getting-started-with-docker).

It is also expected that you have a [basic understanding of Git](http://rogerdudler.github.io/git-guide/) (branching, merging) and some networking (ports, domain names).

# The Radix clusters

Your applications will run in a *Radix cluster*. We currently have three: **Production**, **Production US** and **Playground**. Use Playground for testing Radix and see if it's a good fit for your needs. When your project and team are happy with Radix, you can register your application in one of the Production clusters, which provides [specific guarantees](../../docs/topic-sla/).

**Production** and **Playground** clusters is hosted on Azure North Europe region.

## Production US - Proof of Concept 

**Production US** cluster is hosted on Azure US South Central region, and provides same [specific guarantees](../../docs/topic-sla/) as **Production**. 

**Warning**: This cluster will run as a Proof of Concept (PoC) from mid November 2019 till early January 2020. 

At the end of the PoC period, the Radix team together with participants of the PoC will decide if Radix should continue to be available on cluster running in US. The decisions will be based on activity in the US cluster, and the amount of extra work it is for Radix team to maintain an extra cluster (cost/benefit). The cluster will run until the decision has been made.

If it is decided to continue to support Radix in US - the cluster will change from a PoC to a prod cluster, all apps will continue to run. 

If it is decided to terminate it, the cluster will be kept alive until you have been able to migrate your apps to other hosting alternatives. 

**Anyone can participate in the PoC by simply registering applications in US cluster.**

## Getting access

Access to Radix is managed in Access IT. To get started, decide if you want to try the Playground cluster or go straight to one of the Production clusters. You will have access to register, build, deploy and maintain applications in that cluster.

- Playground cluster: request the role "[Radix Playground Users](https://accessit.equinor.com/Search/Search?term=Radix+Playground+Users+%28OMNIA+RADIX%29)"

- Production clusters: request the role "[Radix Platform Users](https://accessit.equinor.com/Search/Search?term=Radix+Platform+Users+%28OMNIA+RADIX%29)"

You can configure your app in Playground first, and then in Production; there is no special "migrate to production" process. If you have questions, [speak with us on Slack](https://equinor.slack.com/messages/CBKM6N2JY) and we'll help.

# Onboarding

Radix team offer onboarding for teams or projects, where we walk through your application and togheter try to find out if Radix is a good fit for you. Contact us on [slack](https://equinor.slack.com/archives/C8U7XGGAJ) for more information.

# Configure your application

The next step is to [configure your application](../configure-an-app/) on Radix; follow that guide to set things up in the cluster you chose.

(Or, if you prefer reading rather than coding right now, you can get familiar with the [concepts in Radix](../../docs/topic-concepts/) first.)

