# This script is a Foundation version of https://github.com/microsoft/WindowsAppSDK-Samples/blob/main/UpdateVersions.ps1
Param(
    [string]$SampleRepoRoot = "",
    [string]$FoundationVersion = "",
    [string]$FoundationPackagesFolder = "",
    [string]$WASDKPackagesFolder = ""
)

# First, add the metapackage Microsoft.WindowsAppSDK.Foundation
$nugetPackageToVersionTable = @{"Microsoft.WindowsAppSDK.Foundation" = $FoundationVersion}

# Second, if the nuget packages folder is specified containing the latest versions,
# go through them to get the versions of all dependency packages.
if (!($FoundationPackagesFolder -eq ""))
{
    Get-ChildItem $FoundationPackagesFolder | 
    Where-Object { $_.Name -like "Microsoft.WindowsAppSDK.*" -or 
                   $_.Name -like "Microsoft.Windows.SDK.BuildTools.*"} | 
    Where-Object { $_.Name -notlike "*.nupkg" } |
    ForEach-Object { 
        if ($_.Name -match "^(Microsoft\.WindowsAppSDK\.[a-zA-Z]+)\.([0-9].*)$" -or
            $_.Name -match "^(Microsoft\.Windows\.SDK\.BuildTools\.MSIX)\.([0-9].*)$" -or
            $_.Name -match "^(Microsoft\.Windows\.SDK\.BuildTools)\.([0-9].*)$")
        {
            $nugetPackageToVersionTable[$Matches[1]] = $Matches[2]
            Write-Host "Found $($Matches[1]) - $($Matches[2])"
        } 
    }
}
Write-Host "NuGet packages to version table: $($nugetPackageToVersionTable | Out-String)"

# Third, get the Microsoft.WindowsAppSDK and its dependencies
$wasdkDependencies = @("Microsoft.WindowsAppSDK")
if (!($WASDKPackagesFolder -eq ""))
{
    Get-ChildItem $WASDKPackagesFolder | 
    Where-Object { $_.Name -like "Microsoft.WindowsAppSDK.*" -or 
                   $_.Name -like "Microsoft.Windows.SDK.BuildTools.*" -or 
                   $_.Name -like "Microsoft.Web.WebView2.*" } | 
    Where-Object { $_.Name -notlike "*.nupkg" } |
    ForEach-Object { 
        if ($_.Name -match "^(Microsoft\.WindowsAppSDK\.[a-zA-Z]+)\.([0-9].*)$" -or
            $_.Name -match "^(Microsoft\.Windows\.SDK\.BuildTools\.MSIX)\.([0-9].*)$" -or
            $_.Name -match "^(Microsoft\.Windows\.SDK\.BuildTools)\.([0-9].*)$" -or
            $_.Name -match "^(Microsoft\.Web\.WebView2)\.([0-9].*)$")
        {
            $wasdkDependencies += $Matches[1]
            Write-Host "Found $($Matches[1])"
        } 
    }

    Remove-Item -Path $WASDKPackagesFolder -Recurse -Force
    Write-Host "Deleted WASDK packages folder: $WASDKPackagesFolder"
}
Write-Host "WindowsAppSDK dependencies: $($wasdkDependencies | Out-String)"

# Finally, get the packages to remove
$packagesToRemove = @()
foreach ($package in $wasdkDependencies)
{
    if (!$nugetPackageToVersionTable.ContainsKey($package))
    {
        $packagesToRemove += $package
    }
}
Write-Host "Packages to remove: $($packagesToRemove | Out-String)"

Get-ChildItem -Recurse packages.config -Path $SampleRepoRoot | foreach-object {
    $content = Get-Content $_.FullName -Raw

    foreach ($nugetPackageToVersion in $nugetPackageToVersionTable.GetEnumerator())
    {
        $newVersionString = 'package id="' + $nugetPackageToVersion.Key + '" version="' + $nugetPackageToVersion.Value + '"'
        $oldVersionString = 'package id="' + $nugetPackageToVersion.Key + '" version="[-.0-9a-zA-Z]*"'
        $content = $content -replace $oldVersionString, $newVersionString
    }
    foreach ($package in $packagesToRemove)
    {
        $packageReferenceString = '(?m)^\s*<package id="' + $package + '" version="[-.0-9a-zA-Z]*"[^>]*?/>\s*$\r?\n?'
        $content = $content -replace $packageReferenceString, ''
    }

    Set-Content -Path $_.FullName -Value $content
    Write-Host "Modified " $_.FullName 
}

Get-ChildItem -Recurse *.vcxproj -Path $SampleRepoRoot | foreach-object {
    $content = Get-Content $_.FullName -Raw

    foreach ($nugetPackageToVersion in $nugetPackageToVersionTable.GetEnumerator())
    {
        $newVersionString = "\$($nugetPackageToVersion.Key)." + $nugetPackageToVersion.Value + '\'
        $oldVersionString = "\\$($nugetPackageToVersion.Key).[0-9][-.0-9a-zA-Z]*\\"
        $content = $content -replace $oldVersionString, $newVersionString
    }
    foreach ($package in $packagesToRemove)
    {
        $packageReferenceString = "(?m)^.*\\$package\.[0-9][-.0-9a-zA-Z]*\\.*\r?\n?"
        $content = $content -replace $packageReferenceString, ''
    }

    Set-Content -Path $_.FullName -Value $content
    Write-Host "Modified " $_.FullName 
}

Get-ChildItem -Recurse *.wapproj -Path $SampleRepoRoot | foreach-object {
    $newVersionString = 'PackageReference Include="Microsoft.WindowsAppSDK.Foundation" Version="'+ $FoundationVersion + '"'
    $oldVersionString = 'PackageReference Include="Microsoft.WindowsAppSDK" Version="[-.0-9a-zA-Z]*"'
    $content = Get-Content $_.FullName -Raw
    $content = $content -replace $oldVersionString, $newVersionString
    Set-Content -Path $_.FullName -Value $content
    Write-Host "Modified " $_.FullName 
}

Get-ChildItem -Recurse *.csproj -Path $SampleRepoRoot | foreach-object {
    $newVersionString = 'PackageReference Include="Microsoft.WindowsAppSDK.Foundation" Version="'+ $FoundationVersion + '"'
    $oldVersionString = 'PackageReference Include="Microsoft.WindowsAppSDK" Version="[-.0-9a-zA-Z]*"'
    $content = Get-Content $_.FullName -Raw
    $content = $content -replace $oldVersionString, $newVersionString
    Set-Content -Path $_.FullName -Value $content
    Write-Host "Modified " $_.FullName 
}