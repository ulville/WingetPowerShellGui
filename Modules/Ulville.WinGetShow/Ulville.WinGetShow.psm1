<#
 .Synopsis
  Winget show but output is a hashtable.

 .Description
  A wrapper around the winget show command. It takes the output of the command
  and converts it to a powershell hashtable.

 .Parameter Query
  The query used to search for a package.

 .Parameter Id
  Filter results by id.

 .Parameter Name
  Filter results by name .

 .Parameter Moniker
  Filter results by moniker.

 .Example
   # Get winget show info for 7zip as a hashtable
   Get-WinGetPackageInformation -Id 7zip.7zip
#>

function ValidateLineYaml($testSubject) {
    try {
        ConvertFrom-Yaml ($testSubject | Out-String)
        $res = $true
    }
    catch {
        $res = $false
    }
    $res
}

function Get-WinGetPackageInformation {
    param (
        [Alias("q")]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Query,
        [switch]$Id,
        [switch]$Name,
        [switch]$Moniker
    )
    Import-Module powershell-yaml

    $wingetShowArguments = @()
    if ($Id) {
        $wingetShowArguments += "--id"
    }
    if ($Name) {
        $wingetShowArguments += "--name"
    }
    if ($Moniker) {
        $wingetShowArguments += "--moniker"
    }
    $wingetShowArguments += $query
    
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $lines = winget show $wingetShowArguments

    # Find the line that starts with Found, it contains the header
    $fl = 0
    while (-not $lines[$fl].StartsWith("Found")) {
        $fl++
    }
    $packageInfoYaml = $lines[($fl + 1)..($lines.Count - 1)]
    for ($i = 0; $i -lt $packageInfoYaml.Count; $i++) {
        if ($packageInfoYaml[$i] -ceq "Release Notes:") {
            $packageInfoYaml[$i] = "Release Notes: |-"
        }
        elseif ($packageInfoYaml[$i] -like "Release Notes: *") {
            $packageInfoYaml[$i] = $packageInfoYaml[$i].Replace("Release Notes: ", "Release Notes: '") + "'"
        }
    }

    for ($i = 0; $i -lt $packageInfoYaml.Count; $i++) {
        if ($packageInfoYaml[$i] -like "Version: *") {
            $packageInfoYaml[$i] = $packageInfoYaml[$i].Replace("Version: ", "Version: `"") + "`""
        }
    }

    for ($i = 0; $i -lt $packageInfoYaml.Count; $i++) {
        if ($packageInfoYaml[$i] -ceq "Description:") {
            $packageInfoYaml[$i] = "Description: |-"
        }
        elseif ($packageInfoYaml[$i] -like "Description: *") {
            $packageInfoYaml[$i] = $packageInfoYaml[$i].Replace("'", "''")
            $packageInfoYaml[$i] = $packageInfoYaml[$i].Replace("Description: ", "Description: '") + "'"
        }
    }
    for ($i = 0; $i -lt $packageInfoYaml.Count; $i++) {
        if ($packageInfoYaml[$i] -like "Copyright: *") {
            $nextValidLine = 1
            while (-not (ValidateLineYaml($packageInfoYaml[($i + $nextValidLine)..($packageInfoYaml.Count - 1)]))) {
                $nextValidLine++
            }
        
            $packageInfoYaml[$i] = $packageInfoYaml[$i].Replace("Copyright: ", "Copyright: |-`r`n  ")
            for ($l = 1; $l -lt $nextValidLine; $l++) {
                $packageInfoYaml[$i + $l] = "  " + $packageInfoYaml[$i + $l]
            }
        }
    }
    $packageInfo = ConvertFrom-Yaml ($packageInfoYaml | Out-String) -Ordered
    $packageInfo
}

Export-ModuleMember -Function Get-WinGetPackageInformation