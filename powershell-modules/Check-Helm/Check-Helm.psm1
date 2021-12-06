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
    Write-Host "Checking release version.."
    $n = helm ls -A -f ('(?i)^' + $Release) -o json | ConvertFrom-Json
    Write-Host "Checking release version for $n"
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
        Write-Host "Checking chart version.."
        $n = helm search repo -r ('\v' + $Chart + '\v') -o json | ConvertFrom-Json
        if ($n.name -eq $Chart) {
            Write-Host "Found chart for $($n.name) with version $($n.version)"
            $r = $n.version -replace '[a-z-]'
            return $r
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
        $ChartName,
        [Parameter()]
        [string]
        $Cluster
    )
    try {
        $ReleaseVersion = GetReleaseVersion -Release $ReleaseName
        $chartVersion = GetChartVersion -Chart $ChartName
        if ([System.Version]"$chartVersion" -gt [System.Version]"$ReleaseVersion") {
            Write-Host "Found new version for $ReleaseName" -ForegroundColor DarkYellow
            NewWorkItem -ReleaseName $ReleaseName -ReleaseVersion $ReleaseVersion -ChartVersion $chartVersion -Cluster $Cluster
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

# Create a new work item if it does not already exist
function NewWorkItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $ReleaseName,
        [Parameter(Mandatory=$true)]
        [String]
        $ReleaseVersion,
        [Parameter(Mandatory=$true)]
        [String]
        $ChartVersion,
        [Parameter(Mandatory=$true)]
        [String]
        $Cluster
    )
    $WiTitle = "Upgrade $ReleaseName in $Cluster to $ChartVersion - from $ReleaseVersion"
    $qstring = [System.String]::Concat( `
                    "SELECT [system.Id], [System.WorkItemType], [System.Title], [System.State] FROM workitems ", `
                    "WHERE [System.WorkItemType] = 'Technical Work Item' AND [System.State] = 'New' AND [System.Title] = ", "'", "$WiTitle", "' ", `
                    "OR [System.WorkItemType] = 'Technical Work Item' AND [System.State] = 'On Hold' AND [System.Title] = ", "'", "$WiTitle", "' " , `
                    "OR [System.WorkItemType] = 'Technical Work Item' AND [System.State] = 'Active' AND [System.Title] = ", "'", "$WiTitle", "' ")
    try {
        # Check if work item exist
        $wi = (az boards query --wiql $qstring --output json | ConvertFrom-Json).fields.'System.Title'
        if (!$wi) {
            Write-Host "Creating new work item"
            az boards work-item create --title "$WiTitle" --type "Technical Work Item" --description "Old version $ReleaseVersion, new version $ChartVersion" --assigned-to "elirg@equinor.com"
        }
        else {
            Write-Host "Work item already exist"
        }
    }
    catch {
    }
}
