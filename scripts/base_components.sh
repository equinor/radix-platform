# PRECONDITIONS
#
# It is assumed that cluster is installed using the cluster_install.sh script
#
# PURPOSE
#
# The purpose of the shell script is to set up all base
# components of the cluster
#
# To run this script from terminal:
# CLUSTER_NAME=aa HELM_VERSION=bb HELM_REPO=cc ./base_components.sh
#
# Input environment variables:
#   CLUSTER_NAME
#   HELM_VERSION (defaulted if omitted)
#   HELM_REPO

if [ -n "$HELM_VERSION" ]; then
    HELM_VERSION="latest"
fi

# Step 1: Apply RBAC config for helm/tiller
kubectl apply -f ./patch/rbac-config-helm.yaml

echo "Applied RBAC for helm/tiller"

# Step 2: Install Helm
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
get_helm.sh --no-sudo -v "$HELM_VERSION"
helm init --service-account tiller --upgrade --wait

echo "Helm initialized"

# Step 3: Patching kube-dns metrics
kubectl patch deployment -n kube-system kube-dns-v20 --patch ./patch/kube-dns-metrics-patch.yaml

echo "Patched kube-dns metrics"

# Step 4: Adding helm repo
az acr helm repo add --name "$HELM_REPO"
helm repo update
echo "Acr helm repo $HELM_REPO was added"

# Step 5: Stage 0
helm upgrade --install --force radix-stage0 $HELM_REPO/radix-stage0 --namespace default --version 1.0.2
echo "Stage 0 completed"
