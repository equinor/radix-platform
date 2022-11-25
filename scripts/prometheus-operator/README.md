# Prometheus Operator

## Table of contents

- [Refresh secrets](#Refresh-secrets)

### Refresh secrets

Refreshing secrets for Prometheus Operator can be done in 2 steps:
1.  Update `prometheus-token` secret with new password in KV
    1. One way to generate a password is to use `openssl rand -base64 32`. This will generate a 32 character string.
2.	Run [configure.sh](./configure.sh) to update components in kubernetes cluster.
3.  After updating the secrets we need to run [apply_scrape_config.sh](https://github.com/equinor/radix-monitoring/blob/master/cluster-external-monitoring/scripts/kube-prometheus-stack/apply_scrape_config.sh) on `external monitor cluster` to restart the component pods and force it to read the updated k8s secret(s)
