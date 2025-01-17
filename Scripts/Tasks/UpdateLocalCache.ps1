
if ( -not ((Get-Process | Where-Object ProcessName -eq winget) -or (Get-Process | Where-Object ProcessName -eq pwsh | Where-Object CommandLine -Like *WinGetPowerShellGui.ps1*))) {
    $WinGetPSGUIDataDir = "$env:APPDATA\WinGetPowerShellGui\"
    if (-not (Test-Path -Path $WinGetPSGUIDataDir -PathType Container)) {
        New-Item -Path $WinGetPSGUIDataDir -ItemType Directory
    }
    $packageList = Get-WinGetPackage
    $packageList | Export-Clixml -Path "$WinGetPSGUIDataDir\InstalledPackages.xml"
}