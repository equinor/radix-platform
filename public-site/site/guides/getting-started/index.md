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

Your applications will run in a *Radix cluster*. We currently have two: **Production** and **Playground**. Use Playground for testing Radix, see if it's a good fit for your projects, and provide feedback to us. When you are ready to commit, you can register your application in the Production cluster, which has improved stability.

## Getting access

Access to Radix is managed in Access IT. To get started, request the role "[Radix Playground Users](https://accessit.equinor.com/Search/Search?term=Radix+Playground+Users+%28OMNIA+RADIX%29)"; this will grant access to register, build, deploy and maintain applications in the **Playground** cluster.

When you are ready to move to **Production**, come [speak with us on Slack](https://equinor.slack.com/messages/C8U7XGGAJ) and we'll guide you through the process. We expect this to be open in the future and just as easy as getting set up in the Playground.

# Onwards

Let's jump right in and see how to [configure an application](../configure-an-app/) in Radix.

Or, if you prefer reading rather than coding right now, you can read about the [concepts in Radix](../../docs/topic-concepts/) instead.
