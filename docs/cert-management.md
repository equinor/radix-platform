# Certification management

## Summary

1. Certs are provisioned using [cert-manager](./cert-manager.md)
1. One wildcard cert per cluster, stored in a secret
1. The "cluster wildcard" cert is made available for all apps by copying the secret into each app namespace.  
  The tool that handle this synchronization is [KubeD](https://github.com/appscode/kubed).
1. As an app developer you do nothing but sit back and smile, radix will handle all this for you.

## Configuration

_Issuer_  
https://letsencrypt.org  
Be aware of their [rate limit](https://letsencrypt.org/docs/rate-limits/).

_Verification_  
DNS challenge

_Storage_  
Kubernetes secret, type `kubernetes.io/tls`.

_Base components_  
- [Cert-manager](./cert-manager.md)
- [KubeD](https://github.com/appscode/kubed)


## Certificates

| Domain                                        | Usage      | Reference |
| --------------------------------------------- | ---------- | --------- |
| *.cluster-name.environment.radix.equinor.com  | Everything | cluster-wildcard-tls-cert |


## How to configure synchronization
KubeD can synchronize `ConfigMaps` and `Secrets` to namespaces by annotating the source with a sync key, and add a label to the target namespace(s) that reference that sync key.

### Configure source
`ConfigMap` or `Secret`
```yaml
    metadata:
      annotations:
        kubed.appscode.com/sync: "sync=cluster-wildcard-tls-cert" # The value is what we will use as label key/value pair in the target namespace.
```

### Configure targets
Any namespace
```yaml
    metadata:
        labels:
            sync: cluster-wildcard-tls-cert
```

KubeD will now pick up on the changes, copy the secret into the target namespaces and keep them synchronized with the source secret.
