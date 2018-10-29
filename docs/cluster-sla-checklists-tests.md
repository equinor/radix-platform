# Cluster SLAs, checklists and tests

## Playground cluster release 1 - Public alpha

SLA:

  * Security not guaranteed. No sensitive applications or data
  * No uptime or stability guarantees. Can fail at any time.
  * No correctness guarantees. APIs, configs and web console might have bugs/errors.

Tests/success criteria:

  * Canary application
    * Reachable from internet
      * External-DNS
      * HTTPS
  * Web-console
    * Reachable
    * Login
    * Create/delete application
  * Operator
    * Responds to Git Webhook
    * Builds application
    * Deploys application
  * Deployed client application
    * Reachable from internet
  * Monitoring
    * Grafana reachable from internet
      * Login with ADFS
      * Displays data from Prometheus
    * Prometheus pushes data to InfluxDB outside cluster



