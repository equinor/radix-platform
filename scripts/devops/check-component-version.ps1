Install-Module powershell-yaml -Force
Import-Module ".\powershell-modules\Check-Helm\Check-Helm.psm1"
$zoneVariables = Get-Content "scripts\radix-zone\radix_zone_dev.json" | ConvertFrom-Json
az extension add --name azure-devops
az devops configure --defaults organization=https://dev.azure.com/Equinor project=Radix

#Get current active cluster
$activeRadixCluster = (Invoke-WebRequest -Method Get `
    -Uri https://raw.githubusercontent.com/equinor/radix-flux/master/development-configs/radix-platform/radix-operator.yaml | ConvertFrom-Yaml).spec.Values.activeClusterName

az aks get-credentials -n $activeRadixCluster -g $zoneVariables.radix.cluster.resourcegroup --admin

# List of helm repositories used
$repos = @('jetstack https://charts.jetstack.io', 
            'bitnami https://charts.bitnami.com/bitnami', 
            'grafana https://grafana.github.io/helm-charts',
            'fluxcd https://charts.fluxcd.io',
            'ingress-nginx https://kubernetes.github.io/ingress-nginx',
            'appscode https://charts.appscode.com/stable/',
            'kured https://weaveworks.github.io/kured',
            'vmware-tanzu https://vmware-tanzu.github.io/helm-charts')

UpdateRepos -RepoList $repos

CheckRelease -ReleaseName cert-manager -ChartName jetstack/cert-manager
CheckRelease -ReleaseName external-dns -ChartName bitnami/external-dns
CheckRelease -ReleaseName flux -ChartName fluxcd/flux
CheckRelease -ReleaseName grafana -ChartName grafana/grafana
CheckRelease -ReleaseName ingress-nginx -ChartName ingress-nginx/ingress-nginx
CheckRelease -ReleaseName kubed -ChartName appscode/kubed
CheckRelease -ReleaseName kured -ChartName kured/kured
CheckRelease -ReleaseName prometheus-operator -ChartName prometheus-community/kube-prometheus-stack
CheckRelease -ReleaseName velero -ChartName vmware-tanzu/velero