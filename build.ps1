param(
    [string]$npmAuthToken = ""
)

Import-Module ./node_buildscripts_for_teamcity.psm1

$overallStatus = 0;

InjectNpmAuthToken($npmAuthToken)
DownloadNode("v8.11.4")

RunNpmScript -command "install" $false
RunNpmScript -command "run build" $true

if ($env:Git_Branch -eq "refs/heads/master" -and $overallStatus -eq 0) {
    $currentName = Get-NpmPackage-Name
    $currentVersion = Get-NpmPackage-Version
    $existing = RunNpmScript -command "view $currentName@$currentVersion version" $false
    $existing = $existing -replace "`t|`n|`r",""

    Log "Comparing $existing vs $currentVersion."
    if ($existing -ne $currentVersion) {
        Log "nonexisting version detected => Publishing package"
        RunNpmScript -command "publish" $true
    }
}

RunNpmScript -command "run test" $true

if ($overallStatus -gt 0) {
    WriteHeader "Build FAILED!"
    exit(1)
} else {
    WriteHeader "Build SUCCEEDED!"
}

Remove-Module node_buildscripts_for_teamcity
