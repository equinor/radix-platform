ENVIRONMENT ?= dev
CONTAINER_REPO ?= radix$(ENVIRONMENT)
STAGE1_CHART_VERSION = $(shell yq r radix-stage1/Chart.yaml version)
HUMIO_CHART_VERSION = $(shell yq r humio/Chart.yaml version)


update-stage1-repo:
	helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/ 
	helm repo add kubed https://charts.appscode.com/stable/
	az acr helm repo add --name $(CONTAINER_REPO) && helm repo update
	rm -f ./radix-stage1/requirements.lock
	helm dep up ./radix-stage1/
	tar -zcvf radix-stage1-$(STAGE1_CHART_VERSION).tgz radix-stage1
	az acr helm push --name $(CONTAINER_REPO) radix-stage1-$(STAGE1_CHART_VERSION).tgz
	rm -f radix-stage1-$(STAGE1_CHART_VERSION).tgz

update-humio-repo:
	az acr helm repo add --name $(CONTAINER_REPO) && helm repo update
	tar -zcvf humio-$(HUMIO_CHART_VERSION).tgz humio
	az acr helm push --name $(CONTAINER_REPO) humio-$(HUMIO_CHART_VERSION).tgz
	rm -f humio-$(HUMIO_CHART_VERSION).tgz