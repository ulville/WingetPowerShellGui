
if ( -not ((Get-Process | Where-Object ProcessName -eq winget) -or (Get-Process | Where-Object ProcessName -eq pwsh | Where-Object CommandLine -Like *WinGetPowerShellGui.ps1*))) {
    $packageList = Get-WinGetPackage
    $packageList | Export-Clixml -Path "C:\Users\ulvican\AppData\Roaming\WinGetPowerShellGui\InstalledPackages.xml"
}