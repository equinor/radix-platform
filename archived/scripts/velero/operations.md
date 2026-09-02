# Velero operations

Day to day interaction with Velero is done by using the velero client.  
It is important to keep in mind that most of what Velero does is handled through the use of custom resources.  
Knowing this will help you debug most things faster.

Example
```sh
# When Velero run a restore then it will create a "restore" custom resource in the velero namespace.
# View warnings and errors for a restore job using the client
velero restore describe backupname-1234
# Which more or less corrensponds to
kubectl describe -n velero restore/backupname-1234
```


## Velero custom resouces

```sh

# To find all velero CRDs
kubectl get crd --selector=app.kubernetes.io/name=velero

# Custom resources are then created by velero in the velero namespace as needed
# Ex: find all restore jobs
kubectl get restores -n velero

```

## Restore

See [Restore readme](./restore/)


## Velero modes

*To find out which mode velero is in:*
```sh  
   kubectl get deploy/velero -n velero -o=jsonpath='{.spec.template.spec.containers[0].args}'
```

*Set read/write mode:*

```sh
    kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server"]}]}}}}'
```

*Set restore-only mode:*

```sh
    kubectl patch deployment velero -n velero --patch '{"spec": {"template": {"spec": {"containers": [{"name": "velero","args": ["server", "--restore-only"]}]}}}}'
```

(Yes, this is the official way of changing between read only and read write according to Velero Slack)

This behaviour will change in version 1.1 when read/read-write will apply to the storage location rather than the server itself: https://github.com/heptio/velero/pull/1517