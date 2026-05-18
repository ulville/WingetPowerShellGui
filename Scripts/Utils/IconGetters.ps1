$KnownFolderDefinition = @"
using System;
using System.Runtime.InteropServices;
public class KnownFolder {
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
    private static extern int SHGetKnownFolderPath([MarshalAs(UnmanagedType.LPStruct)] Guid rfid, uint dwFlags, IntPtr hToken, out IntPtr pszPath);
    public static string GetPath(string guidString) {
        IntPtr pszPath = IntPtr.Zero;
        try {
            int result = SHGetKnownFolderPath(new Guid(guidString), 0, IntPtr.Zero, out pszPath);
            return result >= 0 ? Marshal.PtrToStringUni(pszPath) : null;
        } finally { if (pszPath != IntPtr.Zero) Marshal.FreeCoTaskMem(pszPath); }
    }
}
"@
Add-Type -TypeDefinition $KnownFolderDefinition

class PackageDetail {
    [string]$Id
    [string]$Name
    [string]$Version
    [string]$LocalIdentifier
    [string]$PackageFamilyName
    [string]$InstallerCategory
    [string]$InstalledArchitecture
    [string]$InstalledLocation
    [string]$OriginSource
}

function Get-PackageNameFromDetailsHeader {
    param ($headerLineText)
    $headerLineText.Split(") ", 2)[1].Split(" [")[0]
}

function Get-PackageIdFromDetailsHeader {
    param ($headerLineText)
    $headerLineText.Split(" [")[1].Split(" [")[-1].Trim("]")
}

function Get-WingetPackegeDetails {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $details = winget list --details
    $headers = $details | Select-String "^\(.*\/.*\).*\[.*\]"

    for ($i = 0; $i -lt $headers.Count; $i++) {
        $header = $headers[$i]

        $pkgDetail = New-Object PackageDetail
        $pkgDetail.Id = Get-PackageIdFromDetailsHeader $header.Line
        $pkgDetail.Name = Get-PackageNameFromDetailsHeader $header.Line


        if ($i -lt $headers.Count - 1) {
            $sectionEnd = $headers[$i + 1].LineNumber - 2
        }
        else {
            $sectionEnd = $details.Count - 1
        }

        $pkgDetailSection = $details[($header.LineNumber)..($sectionEnd)]

        $pkgDetail.Version = ((($pkgDetailSection | Select-String   "^Version: .*").Line) -split ": ")[1]
        $pkgDetail.LocalIdentifier = ((($pkgDetailSection | Select-String   "^Local Identifier: .*").Line) -split ": ")[1]
        $pkgDetail.PackageFamilyName = ((($pkgDetailSection | Select-String   "^Package Family Name: .*").Line) -split ": ")[1]
        $pkgDetail.InstallerCategory = ((($pkgDetailSection | Select-String   "^Installer Category: .*").Line) -split ": ")[1]
        $pkgDetail.InstalledArchitecture = ((($pkgDetailSection | Select-String   "^Installed Architecture: .*").Line) -split ": ")[1]
        $pkgDetail.InstalledLocation = ((($pkgDetailSection | Select-String   "^Installed Location: .*").Line) -split ": ")[1]
        $pkgDetail.OriginSource = ((($pkgDetailSection | Select-String   "^Origin Source: .*").Line) -split ": ")[1]

        $pkgDetail
    }
}

function Get-SafeIcon {
    param(
        [string]$RawPath,
        [int]$IconSize = 24
    )
    if ([string]::IsNullOrWhiteSpace($RawPath)) { return $null }

    # Remove quotes and handle icon indices (e.g., "C:\app.exe,0")
    $cleanPath = $RawPath.Replace('"', '').Split(',')[0]

    if (Test-Path $cleanPath) {
        if ($cleanPath -like "*.png") {
            try {
                return [System.Drawing.Image]::FromFile($cleanPath)
            }
            catch { return $null }
        }
        try {
            return [System.Drawing.Icon]::ExtractIcon($cleanPath, 0, $IconSize)
        }
        catch { return $null }
    }
    return $null
}

function TryGetTargetSizeIcon ($logolist, $size) {
    $targetedLogos = ($logolist | Where-Object BaseName -Like "*targetsize-$size*")
    if ($targetedLogos -and @($targetedLogos).Count -eq 1) {
        return $targetedLogos.FullName
    }
    if ($targetedLogos -and @($targetedLogos).Count -gt 1) {
        $highlyTargetedLogos = $targetedLogos | Where-Object BaseName -Like "*.targetsize-$size"
        if (! $highlyTargetedLogos) {
            return $targetedLogos[0]
        }
        if ($highlyTargetedLogos -and @($highlyTargetedLogos).Count -eq 1) {
            return $highlyTargetedLogos.FullName
        }
        if ($highlyTargetedLogos -and @($highlyTargetedLogos).Count -gt 1) {
            return @($highlyTargetedLogos.FullName)[0]
        }
    }
    return $null
}

function GetPortablePackageIcon {
    param([PackageDetail]$Package)
    $ExeFiles = Get-ChildItem $Package.InstalledLocation -Recurse -Include "*.exe" | Select-Object -ExpandProperty FullName | Sort-Object -Property Length

    # No File Case -------------------

    if (! $ExeFiles) {
        return $null
    }
    # --------------------------------

    # Single File Case ---------------

    if (@($ExeFiles).Count -eq 1) {
        return $ExeFiles
    }
    # --------------------------------

    # Multiple Files Case ------------

    # Check links. If found return that
    $LinksDir = Join-Path $env:LOCALAPPDATA \Microsoft\WinGet\Links
    $Links = Get-ChildItem $LinksDir\*.exe
    $LinkTargets = $Links.LinkTarget

    foreach ($File in $ExeFiles) {
        if ($File -in $LinkTargets) {
            return $File
        }
    }

    # No link found. Look for package name or id
    foreach ($File in $ExeFiles) {
        $BaseName = $File | Split-Path -LeafBase
        if (($Package.Name -like "*${BaseName}*") -or ($Package.Id -like "*${BaseName}*")) {
            return $File
        }
    }

    # Can't find with package name or id. Return shortest file path
    return $ExeFiles[0]
    # --------------------------------
}
function GetMsixPackageIcon {
    param([PackageDetail]$Package, $AppxPackages, [int]$IconSize = 24)

    $StandardIconSizes = @(16, 24, 32, 48, 64, 128, 256)
    $StandardIconSizes = @($StandardIconSizes | Where-Object { $_ -gt $IconSize }) + @($StandardIconSizes | Where-Object { $_ -lt $IconSize } | Sort-Object -Descending)

    # Local Variables
    $PackageFullName = $null
    $AppxPackage = $null
    $Manifest = $null
    $RelativeLogoPath = $null
    $UnregisteredLogo = $null
    $FullLogoPath = $null
    $imagesDirPath = $null
    $icoFile = $null
    $logos = $null
    $logo = $null

    $PackageFullName = $Package.InstalledLocation | Split-Path -Leaf
    $AppxPackage = $AppxPackages | Where-Object PackageFullName -EQ $PackageFullName
    if (! $AppxPackage) { $AppxPackage = $AppxPackages | Where-Object PackageFamilyName -EQ $Package.PackageFamilyName }
    if (! $AppxPackage) { return $null }

    $Manifest = $AppxPackage | Get-AppxPackageManifest
    if (! $Manifest) { return $null }

    $RelativeLogoPath = @($Manifest.Package.Applications.Application.VisualElements.Square30x30Logo)[0]
    if (! $RelativeLogoPath) {
        $RelativeLogoPath = @($Manifest.Package.Applications.Application.VisualElements.Square44x44Logo)[0]
    }
    if (! $RelativeLogoPath) {
        $RelativeLogoPath = @($Manifest.Package.Applications.Application.VisualElements.Square50x50Logo)[0]
    }
    if (! $RelativeLogoPath) {
        $RelativeLogoPath = @($Manifest.Package.Applications.Application.VisualElements.Square55x55Logo)[0]
    }
    if (! $RelativeLogoPath) {
        $RelativeLogoPath = @($Manifest.Package.Applications.Application.VisualElements.Square71x71Logo)[0]
    }
    if (! $RelativeLogoPath) {
        $RelativeLogoPath = @($Manifest.Package.Applications.Application.VisualElements.Square150x150Logo)[0]
    }
    if (! $RelativeLogoPath) {
        $UnregisteredLogo = Get-ChildItem -Path $Package.InstalledLocation -Recurse -Include "*.png"
        if ($UnregisteredLogo) {
            return @($UnregisteredLogo.FullName | Sort-Object -Property Length)[0]
        }
    }
    if (! $RelativeLogoPath) {
        return
    }

    $FullLogoPath = Join-Path $Package.InstalledLocation $RelativeLogoPath

    # Try .ico file first
    $imagesDirPath = Split-Path $FullLogoPath -Parent
    if (Test-Path -Path $imagesDirPath -PathType Container) {
        $icoFile = Get-ChildItem "$imagesDirPath\*.ico"
        if ($icoFile) {
            if ((Get-SafeIcon $icoFile)) {
                return $icoFile
            }
        }
    }

    if (Test-Path -Path $imagesDirPath -PathType Container) {
        $logos = Get-ChildItem -Path "$($FullLogoPath.Replace('.png', '*'))"
    }

    if (! $logos) {
        $UnregisteredLogo = Get-ChildItem -Path $Package.InstalledLocation -Recurse -Include "*.png"
        if ($UnregisteredLogo) {
            return @($UnregisteredLogo.FullName | Sort-Object -Property Length)[0]
        }
    }

    if (! $logos) {
        return $null
    }

    # Single File Case

    if (@($logos).Count -eq 1) {
        return $logos.FullName
    }

    #Multiple Files Case

    # try selectied target size
    $logo = TryGetTargetSizeIcon $logos $IconSize
    if ($logo) {
        return $logo
    }

    # try other standart target sizes
    foreach ($stIconSize in $StandardIconSizes) {
        $logo = TryGetTargetSizeIcon $logos $stIconSize
        if ($logo) {
            return $logo
        }
    }

    # As a fallback return first logo
    $logo = @($logos)[0].FullName
    if ($logo) {
        return $logo
    }
}

function TryGetGUID {
    param([PackageDetail]$Package)
    if ($Package.Id -like "*{*}*") {
        $GUID = $Package.Id | Split-Path -Leaf
    }
    elseif ($Package.LocalIdentifier -like "*{*}*") {
        $GUID = $Package.LocalIdentifier | Split-Path -Leaf
    }
    else {
        $GUID = $null
    }

    return $GUID
}

function GetRegEntry {
    param([PackageDetail]$Package, $RegEntries)

    $RegEntry = $null
    $PackageGUID = TryGetGUID $Package
    if ($PackageGUID) {
        $RegEntry = $RegEntries | Where-Object PSChildName -EQ $PackageGUID
    }
    else {
        $RegEntry = $RegEntries | Where-Object DisplayName -EQ $Package.Name
    }

    return $RegEntry
}

function SanitizePackage {
    param ($PackageName)
    $RegexPatterns = @(
        # 1. Remove ALL parenthetical content completely, except (R) or (TM) strings
        @{ Pattern = '\s*\((?!(R|TM)\s*\))[^)]*\)'; Replace = '' },

        # 2. Remove Turkish version suffix strings (e.g., "2.2.1.0 sürümü")
        @{ Pattern = '\b\d+(\.\d+)+\s+sürümü\b'; Replace = '' },

        # 3. Remove explicit version/release words followed by numbers (e.g., "version 1.6.0")
        @{ Pattern = '\b(version|release)\s+v?\d+(\.\d+)*[a-z]?([\+\-][\w\d\.]+)?'; Replace = '' },

        # 4. Remove version strings with a 'v' or 'V' prefix or Siemens specific SP/UPD tags
        @{ Pattern = '\bv\d+(\.\d+)*(\s*\+\s*SP\d+)?(\s*UPD\d+)?\b'; Replace = '' },

        # 5. Remove standard dot-separated versions, now capturing trailing build numbers (e.g., "21.0.11+10")
        @{ Pattern = '\b\d+\.\d+(\.\d+)*([\+\-][\w\d\.]+)?\b'; Replace = '' },

        # 6. Remove standalone architecture/language tags or leftovers outside parens
        @{ Pattern = '\bSR\d+\b'; Replace = '' },
        @{ Pattern = '\s*-\s*(x86_64|x64|x86|tr-tr|en-US|tr)\b'; Replace = '' },
        @{ Pattern = '\b(x86_64|x64|x86|64\s*bit)\b'; Replace = '' },

        # 7. Clean up any loose trailing punctuation artifacts
        @{ Pattern = '\s*-\s*$'; Replace = '' },

        # 8. Collapse multiple spaces down to a single space
        @{ Pattern = '\s+'; Replace = ' ' }
    )

    $CleanedName = $PackageName
    foreach ($Step in $RegexPatterns) {
        $CleanedName = [regex]::Replace($CleanedName, $Step.Pattern, $Step.Replace, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    $CleanedName.Trim()
}

function SanitizeInstalledLocation {
    param ([string]$Location)
    $Location = $Location.Trim("`"")
    Join-Path (Split-Path $Location -Parent) (Split-Path $Location -Leaf)
}

function TryGetExecutableIcon {
    param ($PackageName, $AppsFolderItems)

    $SanitizedPackageName = SanitizePackage $PackageName
    $appShortcuts = $AppsFolderItems | Where-Object { $_.Name -like "$($SanitizedPackageName)*" }
    if (! $appShortcuts) {
        return $null
    }
    Write-Debug $SanitizedPackageName

    foreach ($appShortcut in $appShortcuts) {
        Write-Debug $appShortcut.Name
    }

    foreach ($appShortcut in $appShortcuts) {
        if (! $appShortcut) {
            continue
        }
        if (($appShortcut.Path | Split-Path -Extension) -ne ".exe") {
            continue
        }

        if (Test-Path -Path $appShortcut.Path -PathType Leaf) {
            if ($Package.InstalledLocation) {
                if ((SanitizeInstalledLocation $Package.InstalledLocation) -like "$(Split-Path $appShortcut.Path -Parent)*") {
                    Write-Debug $appShortcut.Name
                    return $appShortcut.Path
                }
            }
            else {
                Write-Debug $appShortcut.Name
                return $appShortcut.Path
            }
        }

        if ($appShortcut.Path -like "{*}*") {
            $pathParts = $appShortcut.Path.Split("}")
            $KnownFolderID = $pathParts[0] + "}"
            $relPath = $pathParts[1]
            $exePath = Join-Path ([KnownFolder]::GetPath($KnownFolderID)) $relPath
            if (Test-Path -Path $exePath -PathType Leaf) {
                if ($Package.InstalledLocation) {
                    if ((SanitizeInstalledLocation $Package.InstalledLocation) -like "$(Split-Path $exePath -Parent)*") {
                        Write-Debug $appShortcut.Name
                        return $exePath
                    }
                }
                else {
                    Write-Debug $appShortcut.Name
                    return $exePath
                }
            }
        }
    }
}

function GetMsiCacheIcon {
    param (
        $from,
        $packageGuid
    )

    $msInstallerDir = Join-Path $from "\$packageGuid"
    if (! (Test-Path -PathType Container -Path $msInstallerDir)) {
        return $false
    }

    $filesInCache = Get-ChildItem $msInstallerDir

    # If there is a single file and it has an icon. Simply return it
    if ((@($filesInCache).Count -eq 1) -and (Get-SafeIcon $filesInCache)) {
        return $filesInCache
    }

    # Search for .ico files
    $msInstallerIconFiles = (Get-ChildItem "$msInstallerDir\*" -Include "*.ico")
    if (@($msInstallerIconFiles).Count -eq 1) {
        return $msInstallerIconFiles.FullName
    }
    if (@($msInstallerIconFiles).Count -gt 1) {
        $_fileName = ($msInstallerIconFiles | Where-Object Name -Like "*icon*").FullName
        return $_fileName
    }

    $msInstallerIconFiles = (Get-ChildItem "$msInstallerDir\*icon*" -Include "*.exe")
    if (($msInstallerIconFiles) -and ($msInstallerIconFiles.GetType().Name -eq "FileInfo")) {
        return $msInstallerIconFiles.FullName
    }
    if (($msInstallerIconFiles) -and ($msInstallerIconFiles.GetType().Name -eq "Object[]")) {
        $_fileName = ($msInstallerIconFiles | Where-Object Name -Like "*icon*").FullName
        return $_fileName
    }

    $msInstallerIconFiles = (Get-ChildItem "$msInstallerDir\*" -Include "*Icon*", "*icon*", "*ICON*")
    if (($msInstallerIconFiles) -and ($msInstallerIconFiles.GetType().Name -eq "FileInfo")) {
        return $msInstallerIconFiles.FullName
    }
    if (($msInstallerIconFiles) -and ($msInstallerIconFiles.GetType().Name -eq "Object[]")) {
        $_fileName = $msInstallerIconFiles.FullName
        if (($_fileName) -and ($_fileName.GetType().Name -eq "Object[]")) {
            return $_fileName[0]
        }
        return $_fileName
    }

    ####

    $msInstallerIconFiles = (Get-ChildItem "$msInstallerDir\*" -Include "_*.exe")
    if (($msInstallerIconFiles) -and ($msInstallerIconFiles.GetType().Name -eq "FileInfo")) {
        return $msInstallerIconFiles.FullName
    }
    if (($msInstallerIconFiles) -and ($msInstallerIconFiles.GetType().Name -eq "Object[]")) {
        $_fileName = $msInstallerIconFiles.FullName
        if (($_fileName) -and ($_fileName.GetType().Name -eq "Object[]")) {
            return $_fileName[0]
        }
        return $_fileName
    }

    return $false
}

function GetMsiPackageIcon {
    param([PackageDetail]$Package, $RegEntries, $AppsFolderItems)

    Write-Debug "------------------------------------------------------"
    Write-Debug "Name: $($Package.Name)"
    $RegEntry = @(GetRegEntry $Package $RegEntries)[0]
    Write-Debug "Reg Path: $($RegEntry.PSPath | Split-Path -NoQualifier)"

    Write-Debug "DisplayIcon: [$($RegEntry.DisplayIcon)]"
    # Try DisplayIcon property from registry
    if ((Get-SafeIcon $RegEntry.DisplayIcon)) {
        Write-Debug "Found DisplayIcon"
        return $RegEntry.DisplayIcon
    }

    $PackageGUID = $RegEntry.PSChildName
    Write-Debug "GUID: [$($PackageGUID)]"

    # Try to find icon in MSI Cache Directory
    $installerIcon = GetMsiCacheIcon -from (Join-Path $env:SystemRoot "\Installer") -packageGuid $PackageGUID
    if (! $installerIcon) {
        $installerIcon = GetMsiCacheIcon -from (Join-Path $env:APPDATA "\Microsoft\Installer") -packageGuid $PackageGUID
    }
    Write-Debug "InstallerCacheIcon: [$($installerIcon)]"
    if ($installerIcon) {
        Write-Debug "Found Icon in MSI Installer Cache"
        return $installerIcon
    }

    # Try to get icon from main executable
    $execIcon = TryGetExecutableIcon $Package.Name $AppsFolderItems
    Write-Debug "Executable Icon: [$($execIcon)]"
    if (Get-SafeIcon $execIcon) {
        Write-Debug "Found Main Executable Icon"
        return $execIcon
    }

    # Try to get icon from UninstallString property
    Write-Debug "UninstallString: [$($RegEntry.UninstallString)]"
    if (Get-SafeIcon $RegEntry.UninstallString) {
        Write-Debug "Found UninstallString Icon"
        return $RegEntry.UninstallString
    }

    Write-Debug "Found Nothing :("
    Write-Debug ($RegEntry | Format-List | Out-String)
}
function GetExePackageIcon {
    param([PackageDetail]$Package, $RegEntries, $AppsFolderItems)
    return GetMsiPackageIcon $Package $RegEntries $AppsFolderItems
}

function GetPackageIcons {
    param($Packages, [int]$PrefIconSize = 24)

    $iconLUT = @{}
    $AppxPackages = Get-AppxPackage
    $RegPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $RegEntries = Get-ItemProperty $RegPaths -ErrorAction SilentlyContinue
    $Shell = New-Object -ComObject Shell.Application
    $AppsFolder = $Shell.NameSpace("shell:AppsFolder")
    $AppsFolderItems = $AppsFolder.Items()

    $Packages | ForEach-Object {
        $Package = $_
        if (! $iconLUT[$Package.Id]) {
            switch ($Package.InstallerCategory) {
                exe { $iconLUT[$Package.Id] = GetExePackageIcon $Package $RegEntries $AppsFolderItems }
                msi { $iconLUT[$Package.Id] = GetMsiPackageIcon $Package $RegEntries $AppsFolderItems }
                msix { $iconLUT[$Package.Id] = GetMsixPackageIcon $Package $AppxPackages $PrefIconSize }
                portable { $iconLUT[$Package.Id] = GetPortablePackageIcon $Package }
                Default { }
            }
        }
    }

    return $iconLUT
}
