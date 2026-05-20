$WinGetPSGUIDataDir = "$env:APPDATA\WinGetPowerShellGui\"
$InstalledPackagesLocalPath = "$WinGetPSGUIDataDir\InstalledPackages.xml"
$PackageDetailsCachePath = "$WinGetPSGUIDataDir\PackageDetails.xml"
$IconTableCachePath = "$WinGetPSGUIDataDir\IconTable.xml"
$ConfigFile = "$WinGetPSGUIDataDir\Config.json"


if ( -not ((Get-Process | Where-Object ProcessName -eq winget) -or (Get-Process | Where-Object ProcessName -eq pwsh | Where-Object CommandLine -Like *WinGetPowerShellGui.ps1*))) {
    if (-not (Test-Path -Path $WinGetPSGUIDataDir -PathType Container)) {
        New-Item -Path $WinGetPSGUIDataDir -ItemType Directory
    }
    $packageList = Get-WinGetPackage
    $packageList | Export-Clixml -Path $InstalledPackagesLocalPath

    . (Join-Path $PSScriptRoot "..\Utils\IconGetters.ps1" -Resolve)
    $Config = $Config = Get-Content -Path $ConfigFile |  ConvertFrom-Json
    $PackageDetails = Get-WingetPackegeDetails -PackageDetailsCachePath $PackageDetailsCachePath
    GetPackageIcons -Packages $PackageDetails -PrefIconSize $Config.IconSize -IconTableCachePath $IconTableCachePath
}