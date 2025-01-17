[CmdletBinding()]
param (
    [switch]
    $Force
)

# Install Module

$moduleName = "Ulville.WinGetShow"
$moduleSourceDir = "$PSScriptRoot\Modules\$moduleName"

$manifest = Test-ModuleManifest "$moduleSourceDir\$moduleName.psd1" -ErrorAction 0
[string]$version = $manifest.Version

$moduleDir = "${env:USERPROFILE}\Documents\PowerShell\Modules\$moduleName\$version\"

if (-not (Test-Path $moduleDir)) {
    $null = New-Item -Path $moduleDir -ItemType Directory
}

if ($Force) {
    Get-ChildItem $moduleDir | Remove-Item -Recurse
}

Get-ChildItem $moduleSourceDir | Copy-Item -Destination $moduleDir

# Install Scripts

$installDir = "$env:LOCALAPPDATA\Programs\WinGetPowerShellGui"

$scriptsSourceDir = "$PSScriptRoot\Scripts"
$scriptsDir = "$installDir\Scripts\"

if (-not (Test-Path $scriptsDir)) {
    $null = New-Item -Path $scriptsDir -ItemType Directory
}

if ($Force) {
    Get-ChildItem $scriptsDir | Remove-Item -Recurse
}

Get-ChildItem $scriptsSourceDir | Copy-Item -Recurse -Destination $scriptsDir

# Install Tools

$toolsSourceDir = "$PSScriptRoot\Tools"
$toolsDir = "$installDir\Tools\"

if (-not (Test-Path $toolsDir)) {
    $null = New-Item -Path $toolsDir -ItemType Directory
}

if ($Force) {
    Get-ChildItem $toolsDir | Remove-Item -Recurse
}

Get-ChildItem $toolsSourceDir | Copy-Item -Recurse -Destination $toolsDir

# Install Assets

$assetsSourceDir = "$PSScriptRoot\Assets"
$assetsDir = "$installDir\Assets\"

if (-not (Test-Path $assetsDir)) {
    ""
    $null = New-Item -Path $assetsDir -ItemType Directory
}

if ($Force) {
    Get-ChildItem $assetsDir | Remove-Item -Recurse
}

Get-ChildItem $assetsSourceDir | Copy-Item -Recurse -Destination $assetsDir

# Add Scheduled Task

if ($Force) {
    Get-ScheduledTask -TaskName "Update-WingetPSUICache" -TaskPath "\Ulville\" | Unregister-ScheduledTask -Confirm:$false
}

$action = New-ScheduledTaskAction -Execute "${toolsDir}hidden-bat.vbs" -Argument "`"${scriptsDir}Tasks\UpdateLocalCache.ps1`"" -WorkingDirectory "${scriptsDir}Tasks"
$repInterval = New-TimeSpan -Minutes 5
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME" # -RepetitionInterval $repInterval -RepetitionDuration $repDuration
$trigger.Repetition = (New-ScheduledTaskTrigger -once -at "12am" -RepetitionInterval $repInterval).Repetition
$principal = New-ScheduledTaskPrincipal -UserId ulvican -Id Author -RunLevel Limited -LogonType Interactive -ProcessTokenSidType Default
$settings = New-ScheduledTaskSettingsSet -Compatibility Vista
$description = "Store Get-WinGetPackages output object in a file. Update regularly."
$task = New-ScheduledTask -Action $action -Principal $principal -Trigger $trigger -Settings $settings -Description $description
Register-ScheduledTask -TaskPath "\Ulville\" -TaskName "Update-WingetPSUICache" -InputObject $task

# Add Desktop Shortcut

$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut("$env:USERPROFILE\Desktop\WGPSGUI.lnk")
$sc.TargetPath = "$((Get-Command pwsh).Source)"
$sc.Arguments = "-WindowStyle hidden -NoProfile -Command `"${scriptsDir}WinGetPowerShellGui.ps1`""
$sc.Description = "WinGet PowerShell GUI"
$sc.WorkingDirectory = "$env:USERPROFILE"
$sc.Save()

$sc = $ws.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\WGPSGUI.lnk")
$sc.TargetPath = "$((Get-Command pwsh).Source)"
$sc.Arguments = "-WindowStyle hidden -NoProfile -Command `"${scriptsDir}WinGetPowerShellGui.ps1`""
$sc.Description = "WinGet PowerShell GUI"
$sc.WorkingDirectory = "$env:USERPROFILE"
$sc.Save()