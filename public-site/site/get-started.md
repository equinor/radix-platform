---
title: Getting started
layout: page
toc: true
---

# What is Radix?

Omnia Radix is a Platform-as-a-Service ("PaaS", if you like buzzwords). It builds, deploys, and monitors applications, automating the boring stuff and letting you focus on your code. Applications run in <abbr title="someone else's computer">the cloud</abbr> as Docker containers, in environments that you define.

# Requirements

There aren't many requirements: Radix will run applications written in Python, Java, .NET, JavaScript, or [LOLCODE](https://en.wikipedia.org/wiki/LOLCODE) equally well. If it can be built and deployed as Docker containers you are nearly done. If not, it's not hard to "dockerise" most applications: we have guides [TODO: link] and [human help]({% link community.md %}) on hand.

An in-depth understanding of Docker is not a requirement, but it helps to be familiar with the concepts of containers and images. There are many beginner tutorials online, here's one of the most straightforward: [Getting Started with Docker
](https://scotch.io/tutorials/getting-started-with-docker).

# Setting up

Here is what is needed to get your application in Radix:

- A GitHub repository for your code (only GitHub is supported at the moment)
- A `radixconfig.yaml` file that defines the running environments. This must be in the root directory of your repository.
- At least one `Dockerfile` that builds and serves your application. You can have several of these files: one per component, in separate directories (e.g. a "front-end" component and a "back-end" component).

Let's go over these in order.

## Your repository

## The `radixconfig.yaml` file

## A `Dockerfile` per component
