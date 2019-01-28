# Developing

```
cd radix-platform/charts/radix-pipeline-invocation
az acr helm repo add --name radixdev && helm repo update
helm dep up
cd ..
tar -zcvf radix-pipeline-invocation-1.0.9.tgz radix-pipeline-invocation
az acr helm push --name radixdev radix-pipeline-invocation-1.0.9.tgz
```

# Installing

```
helm upgrade --install radix-pipeline-api \
    radixdev/radix-pipeline-invocation \
    --set name="radix-api" \
    --set cloneURL="git@github.com:equinor/radix-api.git" \
    --set pipelineImageTag="release-master"
```


