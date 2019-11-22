---
title: Monitoring your app
layout: document
parent: ['Guides', '../../guides.html']
toc: true
---

# Metrics visualisation

Prometheus and Grafana is the main tools provided in Radix for analytics and monitoring visualisation.

Click the *Monitoring* link in the top right corner of the Radix Web Console, log in to Grafana using Azure AD credentials and explore dashboards.

All dashboards in Radix are shared, i.e. another project/team will also be able to open your dashboard. Therefore, it is a good idea to create a folder for your dashboard with a sensible name. Create your own dashboards from scratch or just make a copy of the sample dashboard and modify the content to meet your needs.

# Standard metrics

By default every application on Radix gets the standard metrics about CPU, memory, disk and network usage out of the box. 

# Application-specific metrics

Developers are encouraged to also export internal metrics. These metrics are automaticaly collected, stored and made available to graph by Radix. Advanced applications sometimes expose hundreds of custom metrics, but even a few help. Start with what's most important for your application to track.

When you add `monitoring: true` to [`radixconfig.yaml`](../../docs/reference-radix-config/#public), Radix will scrape the `/metrics` endpoint on your application expecting metrics in the `Prometheus` format (this is a very simple text-based format).

The Prometheus format looks like this ([full documentation](https://github.com/prometheus/docs/blob/master/content/docs/instrumenting/exposition_formats.md)):

    myapp_internal_queue_size{hostname="myhost",env="dev"} 100
    myapp_worker_pool_size{hostname="myhost",env="dev"} 10

In the first line `myapp_internal_queue_size` is the name of the time-series, and `hostname` and `env` are labels. `100` is the value of the metric right now. It's a good idea to look into the types of metrics; counter, gauge and histogram: [https://prometheus.io/docs/concepts/metric_types/](https://prometheus.io/docs/concepts/metric_types/)

You can either write the handler to construct this format yourself, or use one of the many available [client libraries](https://prometheus.io/docs/instrumenting/clientlibs/).

Radix will now collect these metrics and make them available in your Grafana dashboards.

Once you have started creating and monitoring metrics you might want to [explore the possibilities](../../docs/topic-monitoring/) to make them more useful for your application.

> Metrics information is open (shared) among Radix users. Make sure you do not include confidential information in your metrics. It is suggested that you *prefix* your metric names with your application name (e.g. `<app_name>_metric_name`), so that your application metrics can be easily distinguishable from other application metrics.

## Adding custom metrics to a NodeJS application

Here is a quick example showing how to add custom metrics to a NodeJS Express app. It's based on the examples [here](https://github.com/siimon/prom-client/blob/master/example/server.js) and [here](https://nodejs.org/es/docs/guides/getting-started-guide/).

We will have a single `server.js` file. Comments describe the sections pertaining to monitoring:

```javascript
const express = require('express');
const server = express();

// Import the prometheus-client
const client = require('prom-client');

// Create a register to hold all metrics
const register = client.register;

const hostname = '127.0.0.1';
const port = 3000;

// Create a collector for the default NodeJS metrics that we can run in the background.
// Default metrics include memory heap size, event loop lag, CPU seconds and more.
const collectDefaultMetrics = client.collectDefaultMetrics;

// Probe the default metrics every 5th second.
collectDefaultMetrics({ timeout: 5000 });

// Define a counter
const http_requests = new client.Counter({

  // Name of the counter as it will be stored in Prometheus and used in Grafana
  name: 'http_requests',
    
  // Help text. Not really used anywhere, but set it properly anyway
  help: 'Cumulative number of HTTP requests',
    
  // Extra labels (dimensions) of the metric. For HTTP Requests labels could be path, status_code, method
  // Anything we might want to use later to filter or aggregate subsets of the data
  labelNames: ['path']
});

server.get('/', (req, res) => {
  // Increase the counter with path label /
  http_requests.inc({path: '/'});
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');
  res.end('Hello World\n');
});

server.get('/metrics', (req, res) => {
  // Increase the counter with path label /metrics
  http_requests.inc({path: '/metrics'});
  res.set('Content-Type', register.contentType);
  res.end(register.metrics());
});

server.listen(port, hostname, () => {
    console.log(`Server running at http://${hostname}:${port}/`);
});
```

Before running it you might need to install some dependencies:

    npm install prom-client express

And run it

    node server.js

You can then view the metrics at [http://127.0.0.1:3000/metrics](http://127.0.0.1:3000/metrics).
