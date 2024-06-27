# Work in progress!

Started cililum-26 with these network options:

    AKS_NETWORK_OPTIONS=(
        --network-plugin "azure"
        --network-plugin-mode overlay
        --network-dataplane cilium
    )
Setup Advanced Networking with managed Cilium, but bring your own Grafana/Prometheus
https://learn.microsoft.com/en-us/azure/aks/advanced-network-observability-bring-your-own-cli?tabs=non-cilium

az aks update --resource-group clusters-dev --name cilium-26 --enable-advanced-network-observability
```shell
k get pods -n kube-system -l k8s-app=hubble-relay
# NAME                            READY   STATUS    RESTARTS   AGE
# hubble-relay-55b65f695c-6bnwk   1/1     Running   0          4m9s
```
Level 7 / DNS & HTTP visiblity:
https://docs.cilium.io/en/latest/observability/visibility/#layer-7-protocol-visibility

Note: We should enable --hubble-redact-enabled to redact sensitive http data like query/headers/auth cookies etc

```shell
 kubectl port-forward svc/hubble-ui 12000:80 -n kube-system
```
