[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $RadixEnvironment
)
# Installs powerhsell-yaml for easy conversion to objects
try {
    Install-Module powershell-yaml -Force
}
catch {
    $_
    exit
}


# Imports the modules needed for checking chart versions
Import-Module ".\powershell-modules\Check-Helm\Check-Helm.psm1" -Force

# Imports the radix zone containing values for the environment
$zoneVariables = Get-Content "$RadixEnvironment" | ConvertFrom-Json

# Install devops extension for Azure CLI and add radix as default context
az extension add --name azure-devops
az devops configure --defaults organization=https://dev.azure.com/Equinor project=Radix

#Get current active cluster name
$activeRadixCluster = (Invoke-WebRequest -Method Get `
    -Uri $zoneVariables.radix.cluster.activeclustercheckurl -UseBasicParsing | ConvertFrom-Yaml).spec.postBuild.substitute.ACTIVE_CLUSTER

# Get aks credentials and set it as active context for kubectl and helm
az aks get-credentials -n $activeRadixCluster -g $zoneVariables.radix.cluster.resourcegroup --admin

# List of helm repositories used in Radix
# TODO Add this to a json file so it can be used by other scripts if needed
$repos = @('jetstack https://charts.jetstack.io',
            'blob-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/blob-csi-driver/master/charts',
            'csi-secrets-store-provider-azure https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/charts',
            'bitnami https://charts.bitnami.com/bitnami',
            'dynatrace https://raw.githubusercontent.com/Dynatrace/helm-charts/master/repos/stable',
            'grafana https://grafana.github.io/helm-charts',
            'fluxcd https://github.com/fluxcd/flux/tree/master/chart',
            'ingress-nginx https://kubernetes.github.io/ingress-nginx',
            'appscode https://charts.appscode.com/stable/',
            'kured https://weaveworks.github.io/kured',
            'vmware-tanzu https://vmware-tanzu.github.io/helm-charts',
            'prometheus-community https://prometheus-community.github.io/helm-charts')

UpdateRepos -RepoList $repos

# Runs the check against each component and adds a user story if it detects a new version
# TODO refactor this somehow
CheckRelease -ReleaseName blob-csi-driver -ChartName blob-csi-driver/blob-csi-driver -Cluster $zoneVariables.radix.cluster.type
# CheckRelease -ReleaseName csi-secrets-store-provider-azure -ChartName csi-secrets-store-provider-azure/csi-secrets-store-provider-azure -Cluster $zoneVariables.radix.cluster.type
CheckRelease -ReleaseName cert-manager -ChartName jetstack/cert-manager -Cluster $zoneVariables.radix.cluster.type
# CheckRelease -ReleaseName dynatrace-operator -ChartName dynatrace/dynatrace-operator -Cluster $zoneVariables.radix.cluster.type
CheckRelease -ReleaseName external-dns -ChartName bitnami/external-dns -Cluster $zoneVariables.radix.cluster.type
# CheckRelease -ReleaseName flux -ChartName fluxcd/flux -Cluster $zoneVariables.radix.cluster.type
CheckRelease -ReleaseName grafana -ChartName grafana/grafana -Cluster $zoneVariables.radix.cluster.type
CheckRelease -ReleaseName ingress-nginx -ChartName ingress-nginx/ingress-nginx -Cluster $zoneVariables.radix.cluster.type
CheckRelease -ReleaseName kubed -ChartName appscode/kubed -Cluster $zoneVariables.radix.cluster.type
CheckRelease -ReleaseName kured -ChartName kured/kured -Cluster $zoneVariables.radix.cluster.type
CheckRelease -ReleaseName kube-prometheus-stack -ChartName prometheus-community/kube-prometheus-stack -Cluster $zoneVariables.radix.cluster.type
CheckRelease -ReleaseName velero -ChartName vmware-tanzu/velero -Cluster $zoneVariables.radix.cluster.type
