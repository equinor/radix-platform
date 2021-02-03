#Function for checking what version of a release is installed
function GetReleaseVersion {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Release,
        [Parameter()]
        [string]
        $namespace

    )
    $n = helm ls -A -f ('(?i)^' + $Release) -o json | ConvertFrom-Json
    try {
        $v = $n.chart -replace '[a-z-]'
        Write-Host "Found release $Release with version $v"
        return $v
    }
    catch {
        $_
    }
}

#Function for checking the most up-to-date version for a helm chart
function GetChartVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Chart
    )
    try {
        $n = helm search repo -r ('\v' + $Chart + '\v') -o json | ConvertFrom-Json
        #$n = helm search repo $Chart -o json | ConvertFrom-Json
        if ($n.name -eq $Chart) {
            Write-Host "Found chart for $($n.name) with version $($n.version)"
            $n.version = $n.version -replace '[a-z-]'
            return $n.version
        }
        else {
        Write-Error "Cant find chart $Chart"
        $_
        }
    }
    catch {
        $_
    }
}

#Function for comparing installed release against latest available chart
function CheckRelease {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $ReleaseName,
        [Parameter()]
        [string]
        $ChartName
    )
    try {
        $releaseVersion = GetReleaseVersion -Release $ReleaseName
        $chartVersion = GetChartVersion -Chart $ChartName
        if ([System.Version]"$chartVersion" -gt [System.Version]"$releaseVersion") {
            Write-Host "Found new version for $ReleaseName" -ForegroundColor DarkYellow
        }
        else {
            Write-Host "No new version for $ReleaseName found" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Cant match version. Something went wrong getting versions"
        $_
    }
}

#Takes an array of repos and adds it to the repository list
function UpdateRepos {
    param(
    [Parameter()]
    $RepoList
    )
    Write-Host "list of repos to be added: $RepoList"
    try {
        foreach ($repo in $RepoList) {
            
            
            $n = $repo.Split(" ")
            helm repo add $n.GetValue(0) $n.GetValue(1)
        }
    }
    catch {
    }
    try {
        helm repo update
    }
    catch {
    }
}