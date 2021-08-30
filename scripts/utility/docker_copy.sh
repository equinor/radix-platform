
IMAGE="radix-pipeline:master-latest"

docker pull radixdev.azurecr.io/$IMAGE

docker tag radixdev.azurecr.io/$IMAGE radixclassicdev.azurecr.io/$IMAGE

docker push radixclassicdev.azurecr.io/$IMAGE