[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Init PowerShell Gui
$src = @'
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("User32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'@

Add-Type -Name ConsoleUtils -Namespace Foo -MemberDefinition $src
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

. "$PSScriptRoot\WinGetPackageInfoWindow.ps1"
. "$PSScriptRoot\ControlDefinitions.ps1"

$WinGetPSGUIDataDir = "$env:APPDATA\WinGetPowerShellGui\"
if (-not (Test-Path -Path $WinGetPSGUIDataDir -PathType Container)) {
    Write-Host DataDir Path Not Exists
    New-Item -Path $WinGetPSGUIDataDir -ItemType Directory
}


# $AllPackagesLocalPath = "$WinGetPSGUIDataDir\AllPackages.xml"
$InstalledPackagesLocalPath = "$WinGetPSGUIDataDir\InstalledPackages.xml"

$hide = 0
$show = 1

$hWnd = [Foo.ConsoleUtils]::GetConsoleWindow()
[Foo.ConsoleUtils]::ShowWindow($hWnd, $hide) | Out-Null

[Windows.Forms.Application]::EnableVisualStyles()

# Create a new form
$MainForm = NewMainForm
# $MainForm.Add_Shown({ MainForm_OnShown })

# ELEMENT DEFINITIONS

$tabControl = NewTabControl

$exploreTabPage = NewTabPage "Explore"
$installedTabPage = NewTabPage "Installed"
$updatesTabPage = NewTabPage "Updates"

$tabControl.Controls.Add($exploreTabPage)
$tabControl.Controls.Add($installedTabPage)
$tabControl.Controls.Add($updatesTabPage)
##
## bottomPanel
##
$bottomPanel = NewBottomPanel

###################
## Filling Panel ##
################################################################
$fillingPanel = NewPanel "Fill" -padding "12, 12, 12, 0"
################################################################


## Accept Button ##
###################
## Accept Button. Start Upgrading Selected Packeges or as OK like when nothing is selected or nothing has to be upgraded
# $UpgradeButton = New-Object System.Windows.Forms.Button
# $UpgradeButton.Text = "Upgrade"
# $UpgradeButton.Location = New-Object System.Drawing.Point(
#     ($MainForm.Width - 120), ($MainForm.Height - 90))
# $UpgradeButton.width = 90
# $UpgradeButton.height = 30
# $UpgradeButton.Font = 'Segoe UI,10'
# $UpgradeButton.Anchor = "Bottom, Right"
# $UpgradeButton.DialogResult = [Windows.Forms.DialogResult]::OK
# $MainForm.AcceptButton = $UpgradeButton

$AcceptButton = NewButton "Install" -height 25 -dock "Right"
$AcceptButton.DialogResult = [Windows.Forms.DialogResult]::OK
$MainForm.AcceptButton = $UpgradeButton

$ProgressBar = NewProgressBar
$bottomPanel.Controls.AddRange(@($ProgressBar, $AcceptButton))

$searchBox = NewTextBox -dock "Fill" -margin "3, 4, 6, 3"
$searchButton = NewButton "Search" -margin "3, 3, 6, 3" -height 25

$filterPanel = NewFilterPanel
$searchPanel = NewSearchPanel
$searchPanel.Controls.AddRange(@($searchBox, $searchButton))


$sourceLabel = NewLabel "Source:" -autosize
$searchByLabel = NewLabel "Search By:" -autosize
$sourceComboBox = NewComboBox @("Both", "winget", "msstore")
$searchByComboBox = NewComboBox @("Anything", "Id", "Name", "Moniker")

$filterPanel.Controls.Add($sourceLabel, 0, 0)
$filterPanel.Controls.Add($searchByLabel, 1, 0)
$filterPanel.Controls.Add($sourceComboBox, 0, 1)
$filterPanel.Controls.Add($searchByComboBox, 1, 1)

$explorePanel = NewSizeLimitedPanel 800
$explorePanel.Controls.Add($filterPanel)
$explorePanel.Controls.Add($searchPanel)

$exploreTabPage.Controls.Add($explorePanel)

$searchButton.Add_Click({ Search_Click })

# ListView
$ListView = NewListView
$ListView.Add_MouseDown({ ListView_OnMouseDown })

$fillingPanel.Controls.Add($ListView)

$MainForm.Controls.AddRange(@(
        $fillingPanel, $tabControl, $bottomPanel))


function Search_Click {
    $source = ""
    if ($sourceComboBox.SelectedItem) {
        $source = $sourceComboBox.SelectedItem.ToString()
    }
    $searchBy = ""
    if ($searchByComboBox.SelectedItem) {
        $searchBy = $searchByComboBox.SelectedItem.ToString()
    }
    $ProgressBar.Visible = $true
    $jobby = Start-Job -ScriptBlock $SearchPackages -ArgumentList $searchBox.Text, $source, $searchBy
    Do { [System.Windows.Forms.Application]::DoEvents() } Until ($jobby.State -eq "Completed")
    $res = Get-Job | Receive-Job
    $ProgressBar.Visible = $false
    FillListView -type Explore -packages $res -columns @("Id", "Name", "Version", "Source")
}

function ShowSize {
    $searchBox.Text = "SBox: $($searchBox.Top) $($searchBox.Height) SButton: $($searchButton.Top) $($searchButton.Height)"
}

# Button to Update Package List
# $UpdateButton = New-Object System.Windows.Forms.Button
# $UpdateButton.Text = "Update"
# $UpdateButton.width = 90
# $UpdateButton.height = 30
# $UpdateButton.Location = New-Object System.Drawing.Point(20, 85)
# $UpdateButton.Font = 'Segoe UI,10'
# $UpdateButton.Add_Click({ GetWingetUpdates })
# $UpdateButton.Remove_Click({ GetWingetUpdates })

#### DEBUG BUTTON
# $DebugBreak = New-Object System.Windows.Forms.Button
# $DebugBreak.Text = "Debug Break"
# $DebugBreak.Location = New-Object System.Drawing.Point(($MainForm.Width - 220), ($MainForm.Height - 90))
# $DebugBreak.Add_Click({DebugBreakFunc})
# $DebugBreak.Anchor = 'Bottom, Right'
# function DebugBreakFunc {
#     Write-Host "" # PUT BreakPoint Here!
# }
# $MainForm.controls.Add($DebugBreak)
#### DEBUG BUTTON END



# Status Text
$UpdateStatus = NewLabel -text "Searching for updates..." -location -x 20 -y 140 -autosize
$UpdateStatus.Font = 'Segoe UI,10'


# General Settings Checkboxes
$ListAllPackages = New-Object System.Windows.Forms.CheckBox
$ListAllPackages.AutoSize = $true
$ListAllPackages.Text = "List All Packages"
$ListAllPackages.Location = New-Object System.Drawing.Point(400, 55)
$ListAllPackages.Visible = $true
$ListAllPackages.Add_CheckedChanged({ PopulateListView })

$ShowUndetermined = New-Object System.Windows.Forms.CheckBox
$ShowUndetermined.AutoSize = $true
$ShowUndetermined.Text = "Show Undetermined"
$ShowUndetermined.Location = New-Object System.Drawing.Point(400, 75)
$ShowUndetermined.Visible = $true
$ShowUndetermined.Add_CheckedChanged({ PopulateListView })

$WaitAfterDone = New-Object System.Windows.Forms.CheckBox
$WaitAfterDone.AutoSize = $true
$WaitAfterDone.Text = "Wait After Done"
$WaitAfterDone.Location = New-Object System.Drawing.Point(400, 95)
$WaitAfterDone.Visible = $true

$SelectAll = New-Object System.Windows.Forms.CheckBox
$SelectAll.AutoSize = $true
$SelectAll.Text = "Select All"
$SelectAll.Location = New-Object System.Drawing.Point(400, 115)
$SelectAll.Visible = $false
$SelectAll.Add_Click({ SelectAll_OnClick })

# GroupBox
$GroupBox = New-Object System.Windows.Forms.GroupBox
$GroupBox.Dock = "Top"
$GroupBox.Anchor = 'Bottom, Right, Left, Top'
$GroupBox.Left = 20
$GroupBox.Width = $MainForm.Width - 50
$GroupBox.Height = $MainForm.Height - $GroupBox.Top - 250
$GroupBox.Top = $UpdateStatus.Top
$GroupBox.Text = "Available Updates"
$GroupBox.Font = New-Object System.Drawing.Font(
    'Segoe UI', 10, 
    [System.Drawing.FontStyle]::Bold
)




# Text Which Shows Up When No Upgrades Are Available
$lbAllGood = New-Object System.Windows.Forms.Label
$lbAllGood.Text = "✔️ Packages are up to date"
$lbAllGood.AutoSize = $false
$lbAllGood.TextAlign = "MiddleCenter"
$lbAllGood.Dock = "Fill"
$lbAllGood.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 24 , [System.Drawing.FontStyle]::Bold)
$lbAllGood.ForeColor = "#aaaaaa"



# FUNCTIONS

function ListView_OnMouseDown {
    if ($_.Button -eq "Right") {
        $selectedItem = $ListView.SelectedItems
        Show-WinGetPackageInfoWindow -Id -Query $selectedItem.Text
    }
}

function SelectAll_OnClick() {
    if ($SelectAll.Checked) {
        Foreach ($item in $ListView.Items) {
            $item.checked = $true
        }
    }
    elseif ($ListView.Items.Count -eq $ListView.CheckedItems.Count) {
        foreach ($item in $ListView.Items) {
            $item.Checked = $false
        }
    }
}

function GetSelectedPackageIDs {
    $SelectedPackages = @()
    Foreach ($item in $ListView.CheckedItems) {
        $SelectedPackages += $item.Text
    }
    $SelectedPackages
}

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

function MainForm_OnShown {
    PopulateListView
}

function ListAllPackages_OnCheckedChanged {
    PopulateListView
}

function NewListViewItem {
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Explore", "Installed", "Update")]
        [string]$type,
        [Parameter(Mandatory)]
        $package
    )
    # Column 0 : Id
    $Item = New-Object System.Windows.Forms.ListViewItem($package.Id)
    # Column 1 : Name
    $Item.SubItems.Add($package.Name) | Out-Null

    if ("Explore" -eq $type) { 
        # Column 2 : Version (Latest)
        $Item.SubItems.Add($package.Version) | Out-Null
        # Column 3 : Source
        $Item.SubItems.Add($package.Source) | Out-Null
    }
    if (("Installed" -eq $type) -or ("Update" -eq $type)) {
        # Column 2 : Version (Installed)
        $Item.SubItems.Add($package.InstalledVersion) | Out-Null
        #Column 3 : Last Available Version
        if ($package.AvailableVersions.Count -gt 0) {
            $Item.SubItems.Add($package.AvailableVersions[0]) | Out-Null
        }
        else {
            $Item.SubItems.Add("") | Out-Null
        }
        # Column 4 : Source
        if ($package.Source) {
            $Item.SubItems.Add($package.Source) | Out-Null
        }
    }

    $Item
}

function FillListView {
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Explore", "Installed", "Update")]
        [string]$type,
        $packages,
        [array]$columns
    )
    $ListView.Items.Clear()
    $ListView.Columns.Clear()

    foreach ($column in $columns) {
        $ListView.Columns.Add($column, -2) | Out-Null
    }

    foreach ($package in $packages) {
        $PackageItem = NewListViewItem -type $type -package $package
        $ListView.Items.Add($PackageItem)
    }
    foreach ($Column in $ListView.Columns) {
        $Column.AutoResize("ColumnContent")
        $Column.Width += 20
    }
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


function GetWingetUpdates {

    $UpdateButton.Enabled = $false
    # $UpgradeButton.Enabled = $false
    

    $GroupBox.Controls.Clear()
    
    $UpdateStatus.Visible = $true
    # $Gif.Visible = $true
    $ProgressBar.Enabled = $true
    $ProgressBar.Visible = $true
    $GroupBox.Controls.Add($ProgressBar)
    $jobby = Start-Job -ScriptBlock $GetInstalledPackages
    Do { [System.Windows.Forms.Application]::DoEvents() } Until ($jobby.State -eq "Completed")
    $installedPackages = Get-Job | Receive-Job
    $installedPackages | Export-Clixml -Path $InstalledPackagesLocalPath
    $UpdateStatus.Visible = $false
    # $Gif.Visible = $false
    $ProgressBar.Enabled = $false
    $ProgressBar.Visible = $false
    $UpdateButton.Enabled = $true
    # $UpgradeButton.Enabled = $true
    # $UpgradeButton.Visible = $true
    
    PopulateListView

}


# Add The Elements To The Form
# $MainForm.Controls.AddRange(@(
#         $tabControl, $bottomPanel, $fillingPanel, <# $Title,  $Description, #>$UpdateButton, $UpdateStatus, <# $Gif,#> $SelectAll, 
#         $ShowUndetermined, $ListAllPackages, $WaitAfterDone, <# $UpgradeButton, #> $GroupBox
#     ))

# Display The Form
$formResult = $MainForm.ShowDialog()

# These Will Run After The Form Is Closed

[Foo.ConsoleUtils]::ShowWindow($hWnd, $show) | Out-Null

if ($formResult -eq [Windows.Forms.DialogResult]::OK) {
    switch ($AcceptButton.Text) {
        "Install" {
            
        }
        "Uninstall" {  }
        "Upgrade" {  }
        Default {}
    }
    if ($ListView.CheckedItems.Count -eq 0) {
        Write-Host "Nothing has selected"
        return
    }
    else {
        $SP = ($ListView.SelectedItems | ForEach-Object { $_.Text })
    }
    Write-Host "> sudo winget upgrade $SP"
    sudo winget upgrade $SP
    if ($WaitAfterDone.Checked) {
        Read-Host "Upgrading finished. Press Enter to Exit"
    }
}
else {
    Write-Host "Cancelled"
}

