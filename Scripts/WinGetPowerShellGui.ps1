#Requires -Modules Microsoft.WinGet.Client, Ulville.WinGetShow

# Print Banner
Write-Output "WinGet PowerShell Gui. Loading..."

# Set encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Init PowerShell Gui
$src = @'
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("User32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'@

Add-Type -Name ConsoleUtils -Namespace WGPSGUI -MemberDefinition $src

$dpiSrc = @'
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
'@

Add-Type -Name DPIAwareness -Namespace WGPSGUI -MemberDefinition $dpiSrc

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

. "$PSScriptRoot\Utils\WinGetPackageInfoWindow.ps1"
. "$PSScriptRoot\Utils\ControlDefinitions.ps1"
. "$PSScriptRoot\Utils\IconGetters.ps1"

$WinGetPSGUIDataDir = "$env:APPDATA\WinGetPowerShellGui\"
if (-not (Test-Path -Path $WinGetPSGUIDataDir -PathType Container)) {
    Write-Host DataDir Path Not Exists
    New-Item -Path $WinGetPSGUIDataDir -ItemType Directory
}


# $AllPackagesLocalPath = "$WinGetPSGUIDataDir\AllPackages.xml"
$InstalledPackagesLocalPath = "$WinGetPSGUIDataDir\InstalledPackages.xml"
$PackageDetailsCachePath = "$WinGetPSGUIDataDir\PackageDetails.xml"
$IconTableCachePath = "$WinGetPSGUIDataDir\IconTable.xml"
$configFile = "$WinGetPSGUIDataDir\Config.json"
$Config = $Config = Get-Content -Path $configFile |  ConvertFrom-Json
if (!$Config) {
    $Config = [PSCustomObject]@{
        Size     = $null
        IconSize = 24
    }
}

$hide = 0
$show = 1

$hWnd = [WGPSGUI.ConsoleUtils]::GetConsoleWindow()

[Windows.Forms.Application]::EnableVisualStyles()
[WGPSGUI.DPIAwareness]::SetProcessDPIAware()
switch ($Config.Theme) {
    Dark { $ColorMode = [System.Windows.Forms.SystemColorMode]::Dark }
    Classic { $ColorMode = [System.Windows.Forms.SystemColorMode]::Classic }
    System { $ColorMode = [System.Windows.Forms.SystemColorMode]::System }
    Default { $ColorMode = [System.Windows.Forms.SystemColorMode]::System }
}
[System.Windows.Forms.Application]::SetColorMode($ColorMode)

# Create a new form
$MainForm = NewMainForm -size $Config.Size
$MainForm.Add_Shown({ MainForm_OnShownReal })
$MainForm.Add_FormClosed({ Save_Config })

Write-Host "Creating Tabs" -ForegroundColor DarkYellow

# HIGH LEVEL ELEMENTS

$tabControl = NewTabControl
$tabControl.Add_Selected({ OnTabSelected })

$exploreTabPage = NewTabPage "Explore"
$installedTabPage = NewTabPage "Installed"
$updatesTabPage = NewTabPage "Updates"



$fillingPanel = NewPanel "Fill" -padding "12, 12, 12, 0"

$bottomPanel = NewBottomPanel

Write-Host "Creating Bottom Panel Elements" -ForegroundColor DarkYellow

# IN BOTTOM PANEL

$AcceptButton = NewButton "Install" -height 25 -dock "Right"
$AcceptButton.DialogResult = [Windows.Forms.DialogResult]::OK
# $MainForm.AcceptButton = $AcceptButton

$ProgressBar = NewProgressBar

$RefreshCacheButton = NewButton "`u{e72c}" -height 25 -dock "Left" -font (New-Object System.Drawing.Font("Segoe Fluent Icons", 12))
$RefreshCacheButton.Add_Click({ RefreshCache })

$bottomPanel.Controls.AddRange(@($RefreshCacheButton, $ProgressBar, $AcceptButton))


# TABPAGES

# IN EXPLORE TABPAGE

Write-Host "Creating Explore Tab Elements" -ForegroundColor DarkYellow

$explorePanel = NewSizeLimitedPanel 800
$filterPanel = NewFilterPanel
$searchPanel = NewSearchPanel

# IN SEARCH PANEL - EXPLORE

$searchBox = NewTextBox -dock "Fill" -margin "3, 4, 6, 3"
$searchBox.Add_KeyDown({ searchBox_KeyDown })
function searchBox_KeyDown {
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $searchBox.Multiline = $true
        Search_Click
        $searchBox.Multiline = $false
        # $_.Handled = $true
        # $_.SuppressKeyPress = $true
    }
}
$searchButton = NewButton "Search" -margin "3, 3, 6, 3" -height 25
$searchButton.Add_Click({ Search_Click })

$searchPanel.Controls.AddRange(@($searchBox, $searchButton))

# IN FILTER PANEL - EXPLORE

$sourceLabel = NewLabel "Source:" -autosize
$searchByLabel = NewLabel "Search By:" -autosize
$sourceComboBox = NewComboBox @("Both", "winget", "msstore")
$searchByComboBox = NewComboBox @("Anything", "Id", "Name", "Moniker")

$filterPanel.Controls.Add($sourceLabel, 0, 0)
$filterPanel.Controls.Add($searchByLabel, 1, 0)
$filterPanel.Controls.Add($sourceComboBox, 0, 1)
$filterPanel.Controls.Add($searchByComboBox, 1, 1)

# ADD ELEMENTS TO EXPLORE PANEL/TABPAGE

$explorePanel.Controls.Add($filterPanel)
$explorePanel.Controls.Add($searchPanel)
$exploreTabPage.Controls.Add($explorePanel)

# IN INSTALLED TABPAGE

Write-Host "Creating Installed/Update Tab Elements" -ForegroundColor DarkYellow

$installedPanel = NewSizeLimitedPanel 800
$installedFilterPanel = NewFilterPanel
$installedSearchPanel = NewSearchPanel

# IN SEARCH PANEL - INSTALLED

$installedSearchBox = NewTextBox -dock "Fill" -margin "3, 4, 6, 3"
$installedSearchBox.Add_KeyDown({ installedSearchBox_KeyDown })
function installedSearchBox_KeyDown {
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $installedSearchBox.Multiline = $true
        InstalledSearch_Click
        $installedSearchBox.Multiline = $false
        # $_.Handled = $true
        # $_.SuppressKeyPress = $true
    }
}
$installedSearchButton = NewButton "Search" -margin "3, 3, 6, 3" -height 25
$installedSearchButton.Add_Click({ InstalledSearch_Click })

$installedSearchPanel.Controls.AddRange(@($installedSearchBox, $installedSearchButton))

# IN FILTER PANEL - INSTALLED

$installedSourceLabel = NewLabel "Source:" -autosize
$installedSearchByLabel = NewLabel "Search By:" -autosize
$installedSourceComboBox = NewComboBox @("All", "winget", "msstore", "Other")
$installedSourceComboBox.Add_SelectionChangeCommitted({ InstalledSearch_Click })
$installedSearchByComboBox = NewComboBox @("Anything", "Id", "Name", "Moniker")

$installedFilterPanel.Controls.Add($installedSourceLabel, 0, 0)
$installedFilterPanel.Controls.Add($installedSearchByLabel, 1, 0)
$installedFilterPanel.Controls.Add($installedSourceComboBox, 0, 1)
$installedFilterPanel.Controls.Add($installedSearchByComboBox, 1, 1)

# ADD ELEMENTS TO INSTALLED PANEL/TABPAGE

$installedPanel.Controls.Add($installedFilterPanel)
$installedPanel.Controls.Add($installedSearchPanel)
$installedTabPage.Controls.Add($installedPanel)

# ADD ELEMENTS TO UPDATE PANEL/TABPAGE

$selectAllPanel = NewSearchPanel
$updatesPanel = NewSizeLimitedPanel 800

$selectAll = NewCheckbox -text "Select All" -padding "2, 0, 6, 3"
$selectAll.Add_Click({ SelectAll_OnClick })
$selectAllPanel.Controls.Add($selectAll)
$updatesPanel.Controls.Add($selectAllPanel)
$updatesTabPage.Controls.Add($updatesPanel)

# ADD TABPAGES TO TAB CONTROL
$dummyTabPage = NewTabPage "Dummy"

$tabControl.Controls.AddRange(@($dummyTabPage, $exploreTabPage, $installedTabPage, $updatesTabPage))
# $tabControl.Controls.Add($exploreTabPage)
# $tabControl.Controls.Add($installedTabPage)
# $tabControl.Controls.Add($updatesTabPage)

# FILLING (MID) PANEL

# LISTVIEWS

Write-Host "Getting winget list details" -ForegroundColor DarkYellow

$details = Get-WingetPackegeDetails -PackageDetailsCachePath $PackageDetailsCachePath

Write-Host "Creating Listviews" -ForegroundColor DarkYellow

$exploreListView = NewListView
$installedListView = NewListView
$updatesListView = NewListView

Write-Host "Filling Icon Lookup Table" -ForegroundColor DarkYellow

$iconLookup = GetPackageIcons $details $Config.IconSize -IconTableCachePath $IconTableCachePath

Write-Host "Creating Image List object" -ForegroundColor DarkYellow

$imageList = New-Object System.Windows.Forms.ImageList
$imageList.ImageSize = New-Object System.Drawing.Size($Config.IconSize, $Config.IconSize)
$imageList.ColorDepth = "Depth32Bit"

# Default Icon
$defaultIcon = [System.Drawing.Icon]::ExtractIcon("$env:SystemRoot\system32\shell32.dll", 2, $Config.IconSize)
$imageList.Images.Add($defaultIcon)

Write-Host "Filling Image List with icons in Icon Lookup Table" -ForegroundColor DarkYellow

$icon_count = 1
$reverse_icon_map = @{}
foreach ($iconLookupItem in $iconLookup.GetEnumerator()) {
    $extracted_icon = Get-SafeIcon $iconLookupItem.Value $Config.IconSize
    if (! $extracted_icon) {
        continue
    }
    $reverse_icon_map.Add($iconLookupItem.Key, $icon_count)
    $icon_count = $icon_count + 1

    $imageList.Images.Add($extracted_icon)
}

Write-Host "Set ListView SmallImageLists as Image List" -ForegroundColor DarkYellow

$installedListView.SmallImageList = $imageList
$installedListView.LargeImageList = $imageList
$updatesListView.SmallImageList = $imageList
$updatesListView.LargeImageList = $imageList

$exploreListView.Add_MouseDown({ ListView_OnMouseDown })
$installedListView.Add_MouseDown({ ListView_OnMouseDown })
$updatesListView.Add_MouseDown({ ListView_OnMouseDown })

$updatesListView.Add_ItemChecked({ ListView_OnItemChecked })

$fillingPanel.Controls.Add($exploreListView)
# $fillingPanel.Controls.Add($installedListView)
# $fillingPanel.Controls.Add($updatesListView)

# ADD SUB-CONTAINERS TO MAIN WINDOW

$MainForm.Controls.AddRange(@($fillingPanel, $tabControl, $bottomPanel))


# FUNCTIONS

# EVENT CALLBACK FUNCTIONS

function OnTabSelected {
    switch ($_.TabPageIndex) {
        # Explore
        0 {
            $fillingPanel.Controls.Clear()
            $fillingPanel.Controls.Add($exploreListView)
            $AcceptButton.Text = "Install"
            UpdateTileSize $exploreListView
            $originalWidth = $exploreListView.Width
            $exploreListView.Width = $originalWidth - 1
            $exploreListView.Width = $originalWidth
        }
        # Installed
        1 {
            $fillingPanel.Controls.Clear()
            $fillingPanel.Controls.Add($installedListView)
            $AcceptButton.Text = "Uninstall"
            UpdateTileSize $installedListView
            $originalWidth = $installedListView.Width
            $installedListView.Width = $originalWidth - 1
            $installedListView.Width = $originalWidth
        }
        # Updates
        2 {
            $fillingPanel.Controls.Clear()
            $fillingPanel.Controls.Add($updatesListView)
            $AcceptButton.Text = "Upgrade"
            UpdateTileSize $updatesListView
            $originalWidth = $updatesListView.Width
            $updatesListView.Width = $originalWidth - 1
            $updatesListView.Width = $originalWidth
        }
        Default {}
    }
}

function ListView_OnMouseDown {
    if ($_.Button -eq "Right") {
        $selectedItem = $this.SelectedItems[0]
        [System.Windows.Forms.ListViewItem+ListViewSubItemCollection]$subitems = $selectedItem.SubItems
        $indexOfAvailableVersion = $subitems.IndexOfKey("Available")
        $indexOfId = $subitems.IndexOfKey("Id")
        $availableVersion = $subitems[$indexOfAvailableVersion].Tag
        $IdOfSelectedItem = $subitems[$indexOfId].Tag
        Show-WinGetPackageInfoWindow -Id -Query $IdOfSelectedItem -Version $availableVersion
    }
}

function ListView_OnItemChecked {

    $isAllSelected = $true
    $isNoneSelected = $true
    foreach ($item in $this.Items) {
        if ($item.Checked) {
            $isNoneSelected = $false
        }
        $isAllSelected = $isAllSelected -and $item.Checked
    }
    if ($isAllSelected) {
        $selectAll.CheckState = "Checked"
    }
    elseif ($isNoneSelected) {
        $selectAll.CheckState = "Unchecked"
    }
    else {
        $selectAll.CheckState = "Indeterminate"
    }
}

function Search_Click {
    $source = ""
    if ($sourceComboBox.SelectedItem) {
        $source = $sourceComboBox.SelectedItem.ToString()
    }
    $searchBy = ""
    if ($searchByComboBox.SelectedItem) {
        $searchBy = $searchByComboBox.SelectedItem.ToString()
    }
    # $res = AsyncRun -ScriptBlock $SearchPackages -ArgumentList $searchBox.Text, $source, $searchBy
    startTimer -LongWork $SearchPackages -LongWorkArgs $searchBox.Text, $source, $searchBy -PostAction "Search_Click"
}

function InstalledSearch_Click {
    $installedPackages = GetInstalledPackages -PostAction "InstalledSearch_Click"
    if ($installedPackages) {
        $source = ""
        if ($installedSourceComboBox.SelectedItem) {
            $source = $installedSourceComboBox.SelectedItem.ToString()
        }
        $searchBy = ""
        if ($installedSearchByComboBox.SelectedItem) {
            $searchBy = $installedSearchByComboBox.SelectedItem.ToString()
        }

        switch ($source) {
            "" { $filteredPackages = $installedPackages }
            "All" { $filteredPackages = $installedPackages }
            "Other" { $filteredPackages = $installedPackages | Where-Object Source -NE "winget" | Where-Object Source -NE "msstore" }
            Default { $filteredPackages = $installedPackages | Where-Object Source -EQ $source }
        }

        if ($installedSearchBox.Text -ne "") {
            switch ($searchBy) {
                "Id" { $searchResult = $filteredPackages | Where-Object Id -Like "*$($installedSearchBox.Text)*" }
                "Name" { $searchResult = $filteredPackages | Where-Object Name -Like "*$($installedSearchBox.Text)*" }
                Default {
                    $searchResult = $filteredPackages |
                    Where-Object { ($_.Id -Like "*$($installedSearchBox.Text)*") -or
                        ($_.Name -Like "*$($installedSearchBox.Text)*") }
                }
            }
        }
        else {
            $searchResult = $filteredPackages
        }

        FillListView -type Installed `
            -packages $searchResult `
            -columns @("Name", "Id", "Version", "Available", "Source")
        # $res = AsyncRun -ScriptBlock $SearchPackages -ArgumentList $searchBox.Text, $source, $searchBy
        # FillListView -type Explore -packages $res -columns @("Id", "Name", "Version", "Source")
    }
}

function RefreshCache {
    Remove-Item -Path $InstalledPackagesLocalPath
    MainForm_OnShown
}

function SelectAll_OnClick() {
    if ($SelectAll.Checked) {
        Foreach ($item in $updatesListView.Items) {
            $item.checked = $true
        }
    }
    elseif ($updatesListView.Items.Count -eq $updatesListView.CheckedItems.Count) {
        foreach ($item in $updatesListView.Items) {
            $item.Checked = $false
        }
    }
}

# function GetSelectedPackageIDs {
#     $SelectedPackages = @()
#     Foreach ($item in $ListView.CheckedItems) {
#         $SelectedPackages += $item.Text
#     }
#     $SelectedPackages
# }

# SCRIPT BLOCKS

$GetInstalledPackages =
{
    $packageList = Get-WinGetPackage
    $packageList
}

$SearchPackages =
{
    param(
        $query,
        $source,
        $searchBy
    )
    switch ($searchBy) {
        "Id" { $HashArguments = @{Id = $query } }
        "Name" { $HashArguments = @{Name = $query } }
        "Moniker" { $HashArguments = @{Moniker = $query } }
        Default { $HashArguments = @{Query = $query } }
    }
    if ($source -and ($source -ne "Both")) {
        $HashArguments.Add("Source", $source)
    }
    $foundPackages = Find-WinGetPackage @HashArguments
    $foundPackages
}

function Save_Config {
    $Config.Size = $this.ClientSize.Width.ToString() + ", " + $this.ClientSize.Height.ToString()
    $Config | ConvertTo-Json | Out-File -FilePath $configFile
}

function MainForm_OnShownReal {
    MainForm_OnShown
    $tabControl.Controls.RemoveAt(0)
    UpdateTileSize $exploreListView
    UpdateTileSize $installedListView
    UpdateTileSize $updatesListView
}

function GetIsUpdateAvailable {
    param ($Package)
    if ($Package.IsUpdateAvailable -eq "True") {
        return $true
    }

    try {
        $LastAvailableVersion = [System.Version]($Package.AvailableVersions)[0]
        $InstalledVersion = [System.Version]$Package.InstalledVersion
        return ($LastAvailableVersion -gt $InstalledVersion)
    }
    catch {
        return $false
    }
}

function MainForm_OnShown {
    $installedPackages = GetInstalledPackages -PostAction "MainForm_OnShown"
    if ($installedPackages) {
        $updatablePackages = $installedPackages | Where-Object { GetIsUpdateAvailable $_ }
        $determinedUpdatablePackages = $updatablePackages | Where-Object InstalledVersion -NE "Unknown"

        FillListView -type Installed `
            -packages $installedPackages `
            -columns @("Name", "Id", "Version", "Available", "Source")

        FillListView -type Update `
            -packages $determinedUpdatablePackages `
            -columns @("Name", "Id", "Version", "Available", "Source")
    }

    # $MainForm.Close() # trace
}

# function ListAllPackages_OnCheckedChanged {
#     PopulateListView
# }

function IsInstalled {
    param (
        $package,
        $installedPackages
    )
    $result = ($package.Id -in $installedPackages.Id)
    $result
}

function FillListView {
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Explore", "Installed", "Update")]
        [string]$type,
        $packages,
        [array]$columns,
        $installedPackages
    )
    switch ($type) {
        "Explore" { $ListView = $exploreListView }
        "Installed" { $ListView = $installedListView }
        "Update" { $ListView = $updatesListView }
        Default {}
    }
    $ListView.Items.Clear()
    $ListView.Columns.Clear()

    foreach ($column in $columns) {
        $ListView.Columns.Add($column, -2) | Out-Null
    }

    foreach ($package in $packages) {
        $params = @{
            type              = $type
            package           = $package
            InstalledPackages = $installedPackages
            PackageDetails    = $details
            icon              = ([bool]($type -ne "Explore"))
        }
        $PackageItem = NewListViewItem @params
        $ListView.Items.Add($PackageItem)
    }
    foreach ($Column in $ListView.Columns) {
        $Column.AutoResize("ColumnContent")
        $Column.Width += 20
    }
    $naturalWidths = @(
        @{"ListView" = $exploreListView; "NaturalWidth" = 0 },
        @{"ListView" = $installedListView; "NaturalWidth" = 0 },
        @{"ListView" = $updatesListView; "NaturalWidth" = 0 }
    )
    foreach ($nw in $naturalWidths) {
        foreach ($column in $nw.ListView.Columns) {
            $nw["NaturalWidth"] += $column.Width
        }
    }
    # $biggestNaturalWidth = [System.Math]::Max(
    #     ([System.Math]::Max($naturalWidths[0].NaturalWidth, $naturalWidths[1].NaturalWidth)),
    #     $naturalWidths[2].NaturalWidth
    # )
    # $oldWidth = $MainForm.Width
    # $MainForm.Width = $biggestNaturalWidth + 61
    # $MainForm.Left = $MainForm.Location.X - (($MainForm.Width - $oldWidth) / 2)

    $ListView
}

# function PopulateListView {

#     $installedPackages = Import-Clixml -Path $InstalledPackagesLocalPath

#     # $updateablePackages = $installedPackages | Where-Object IsUpdateAvailable -Eq "True"
#     # $determinedUpdateablePackages = $updateablePackages | Where-Object InstalledVersion -NE "Unknown"
#     $PackagesToShow = $installedPackages
#     if ( -not $ListAllPackages.Checked) {
#         $PackagesToShow = $PackagesToShow | Where-Object IsUpdateAvailable -Eq "True"
#         if ( -not $ShowUndetermined.Checked) {
#             $PackagesToShow = $PackagesToShow | Where-Object InstalledVersion -NE "Unknown"
#         }
#     }
#     $SelectAll.Visible = $true
#     $ListView.Items.Clear()
#     foreach ($package in $PackagesToShow) {
#         $PackageItem = New-Object System.Windows.Forms.ListViewItem($package.Id)
#         $PackageItem.SubItems.Add($package.Name)
#         $PackageItem.SubItems.Add($package.InstalledVersion)
#         if ($package.AvailableVersions.Count -gt 0) {
#             $PackageItem.SubItems.Add($package.AvailableVersions[0])
#         }
#         $ListView.Items.Add($PackageItem)
#     }

#     if ($PackagesToShow.Length -eq 0) {
#         # $UpgradeButton.Text = "OK"
#         $GroupBox.Controls.Add($lbAllGood)
#     }
#     else {
#         # $UpgradeButton.Text = "Upgrade"
#         $GroupBox.Controls.Add($ListView)
#         foreach ($Column in $ListView.Columns) {
#             $Column.AutoResize("ColumnContent")
#             $Column.Width += 20
#         }
#     }
# }

function IsCacheAvailable {
    Test-Path -Path $InstalledPackagesLocalPath -PathType Leaf
}

function IsCacheFresh ([double]$freshnessLimitInSecs = 60) {
    $lastWriteTime = (Get-ChildItem $InstalledPackagesLocalPath).LastWriteTime
    $timeDiffSec = ((Get-Date) - $lastWriteTime).TotalSeconds
    $res = ($timeDiffSec -le $freshnessLimitInSecs)
    $res
}

function GetInstalledPackages($PostAction) {
    if ((IsCacheAvailable) -and (IsCacheFresh 300)) {
        $installedPackages = Import-Clixml -Path $InstalledPackagesLocalPath
        $installedPackages
    }
    else {
        startTimer -LongWork $GetInstalledPackages -PostAction $PostAction | Out-Null
        # startTimer -LongWork $GetInstalledPackages -PostAction $PostAction | Out-Null
        return $false
        # $installedPackages = AsyncRun -ScriptBlock $GetInstalledPackages
        # $installedPackages | Export-Clixml -Path $InstalledPackagesLocalPath
        # $installedPackages = Import-Clixml -Path $InstalledPackagesLocalPath
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 250
$timer.Add_Tick({ On_Tick })

function On_Tick() {
    $MyJob = Get-Job -Name "WinGetPwShGUI_Background_Job"
    # Runs on every tick

    if ($MyJob.State -eq "Completed") {
        # Runs after job has completed
        $JobResult = $MyJob | Receive-Job
        $LongWorkResult = $JobResult.LongWorkResult
        $PostAction = $JobResult.PostAction
        stopTimer

        switch ($PostAction) {
            "MainForm_OnShown" {
                $installedPackages = $LongWorkResult
                $installedPackages | Export-Clixml -Path $InstalledPackagesLocalPath
                $installedPackages = Import-Clixml -Path $InstalledPackagesLocalPath
                MainForm_OnShown
            }
            "InstalledSearch_Click" {
                $installedPackages = $LongWorkResult
                $installedPackages | Export-Clixml -Path $InstalledPackagesLocalPath
                $installedPackages = Import-Clixml -Path $InstalledPackagesLocalPath
                InstalledSearch_Click
            }
            "Search_Click" {
                $installedPackages = Import-Clixml -Path $InstalledPackagesLocalPath
                FillListView -type Explore -packages $LongWorkResult -columns @("Name", "Id", "Version", "Source") -installedPackages $installedPackages
            }
            Default {}
        }

    }
}

function startTimer() {
    param(
        $LongWork,
        $LongWorkArgs,
        $PostAction
    )
    $RunnerArgs = @{
        LongWork     = $LongWork
        LongWorkArgs = $LongWorkArgs
        PostAction   = $PostAction
    }
    Start-Job -ScriptBlock $LongWorkRunner -ArgumentList $RunnerArgs -Name "WinGetPwShGUI_Background_Job"
    $ProgressBar.Visible = $true
    $timer.Start()

}

$LongWorkRunner = {
    param(
        $RunnerArgs
    )
    $LongWork = $RunnerArgs.LongWork
    $LongWorkArgs = $RunnerArgs.LongWorkArgs
    $PostAction = $RunnerArgs.PostAction
    $sbLongWork = [scriptblock]::Create($LongWork)

    $LongWorkResult = Invoke-Command -ScriptBlock $sbLongWork -ArgumentList $LongWorkArgs

    $ResultWithPostAction = @{
        LongWorkResult = $LongWorkResult
        PostAction     = $PostAction
    }

    $ResultWithPostAction
}

function stopTimer() {
    $timer.Enabled = $false
    Get-Job -Name "WinGetPwShGUI_Background_Job" | Stop-Job
    Get-Job -Name "WinGetPwShGUI_Background_Job" | Remove-Job
    $ProgressBar.Visible = $false
}


# Add The Elements To The Form
# $MainForm.Controls.AddRange(@(
#         $tabControl, $bottomPanel, $fillingPanel, <# $Title,  $Description, #>$UpdateButton, $UpdateStatus, <# $Gif,#> $SelectAll,
#         $ShowUndetermined, $ListAllPackages, $WaitAfterDone, <# $UpgradeButton, #> $GroupBox
#     ))

# Hide Terminal Window

Write-Host "Hiding Terminal Window" -ForegroundColor DarkYellow

[WGPSGUI.ConsoleUtils]::ShowWindow($hWnd, $hide) | Out-Null

# Set Dark Theme

# ApplyDarkTheme -Control $MainForm

# Display The Form
$formResult = $MainForm.ShowDialog()

# These Will Run After The Form Is Closed

[WGPSGUI.ConsoleUtils]::ShowWindow($hWnd, $show) | Out-Null

if ($formResult -eq [Windows.Forms.DialogResult]::OK) {
    switch ($AcceptButton.Text) {
        "Install" {
            $subcommand = "install"
            $ListView = $exploreListView
        }
        "Uninstall" {
            $subcommand = "uninstall"
            $ListView = $installedListView
        }
        "Upgrade" {
            $subcommand = "upgrade"
            $ListView = $updatesListView
        }
        Default {}
    }
    if ($ListView.SelectedItems.Count -eq 0) {
        Write-Host "Nothing has selected"
        return
    }
    else {
        $LVSelectedItems = $ListView.SelectedItems
        $SelectedPacks = $LVSelectedItems | ForEach-Object {
            [System.Windows.Forms.ListViewItem+ListViewSubItemCollection]$subitems = $_.SubItems
            $indexOfId = $subitems.IndexOfKey("Id")
            $IdOfCheckedItem = $subitems[$indexOfId].Tag
            "`"$($IdOfCheckedItem)`""
        }
    }
    Write-Host "> sudo winget $subcommand $SelectedPacks"
    sudo winget $subcommand $SelectedPacks
    Remove-Item -Path $InstalledPackagesLocalPath
    $packageList = Get-WinGetPackage
    $packageList | Export-Clixml -Path $InstalledPackagesLocalPath
    # if ($WaitAfterDone.Checked) {
    Read-Host "Process finished. Press Enter to Exit"
    # }
}
else {
    Write-Host "Cancelled"
}

