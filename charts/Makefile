ENVIRONMENT ?= dev
CONTAINER_REPO ?= radix$(ENVIRONMENT)
STAGE1_CHART_VERSION = $(shell cat radix-stage1/Chart.yaml | yq --raw-output .version)


update-stage1-repo:
	helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/ 
	helm repo add kubed https://charts.appscode.com/stable/
	az acr helm repo add --name $(CONTAINER_REPO) && helm repo update
	rm -f ./radix-stage1/requirements.lock
	helm dep up ./radix-stage1/
	tar -zcvf radix-stage1-$(STAGE1_CHART_VERSION).tgz radix-stage1
	az acr helm push --name $(CONTAINER_REPO) radix-stage1-$(STAGE1_CHART_VERSION).tgz
	rm -f radix-stage1-$(STAGE1_CHART_VERSION).tgz
