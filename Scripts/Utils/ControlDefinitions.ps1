Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function NewMainForm($size) {
    $MainForm = New-Object System.Windows.Forms.Form
    if (!$size) {
        $size = '566,550'
    }
    $MainForm.ClientSize = $size
    $MainForm.Text = "WinGet Powershell GUI"
    $MainForm.StartPosition = "CenterScreen"
    $MainForm.MinimumSize = New-Object System.Drawing.Size(320, 400)
    $MainForm.Icon = New-Object System.Drawing.Icon("$PSScriptRoot\..\..\Assets\icon_v2.ico")
    $MainForm.Add_Resize({ MainForm_OnResize })
    # $MainForm.Padding = 12
    $MainForm
}

function NewTabControl() {
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Dock = "Top"
    $tabControl.Height = 142
    $tabControl.Padding = "18, 6"
    $tabControl
}

function NewTabPage ([string]$text) {
    $tabPage = New-Object System.Windows.Forms.TabPage
    $tabPage.Text = $text
    # $tabPage.UseVisualStyleBackColor = $true
    $tabPage.Padding = 12
    $tabPage
}

function NewPanel ($dock, $bgcolor, $height, $padding) {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = $dock
    if ($bgcolor) {
        $panel.BackColor = $bgcolor
    }
    if ($height) {
        $panel.Height = $height
    }
    if ($padding) {
        $panel.Padding = $padding
    }
    $panel
}

function NewSizeLimitedPanel {
    param (
        $maxWidth
    )
    $sizeLimPanel = New-Object System.Windows.Forms.Panel
    $sizeLimPanel.Anchor = "Top, Bottom, Left, Right"
    $sizeLimPanel.AutoSize = $true
    $sizeLimPanel.Padding = 6
    $sizeLimPanel.MaximumSize = New-Object System.Drawing.Size($maxWidth, 0)
    # $sizeLimPanel.BackColor = "#ff0000"
    $sizeLimPanel
}

function NewSearchPanel {
    param (
        $height
    )
    $tlPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $tlPanel.AutoSize = $true
    $tlPanel.ColumnCount = 2
    $tlPanel.ColumnStyles.Add((
            New-Object System.Windows.Forms.ColumnStyle("Percent", 100.0)
        )) | Out-Null
    $tlPanel.ColumnStyles.Add((
            New-Object System.Windows.Forms.ColumnStyle
        )) | Out-Null
    $tlPanel.Dock = "Top"
    $tlPanel.Padding = "6, 5, 6, 5"
    if ($height) {
        $tlPanel.Height = $height
    }

    # $tlPanel.BackColor = "#00ff00"

    $tlPanel
}

function NewFilterPanel {
    param (
        $height
    )

    $tlPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $tlPanel.AutoSize = $true
    $tlPanel.ColumnCount = 2
    $tlPanel.ColumnStyles.Add((
            New-Object System.Windows.Forms.ColumnStyle("Percent", 50.0)
        )) | Out-Null
    $tlPanel.ColumnStyles.Add((
            New-Object System.Windows.Forms.ColumnStyle("Percent", 50.0)
        )) | Out-Null
    $tlPanel.Dock = "Top"
    $tlPanel.Padding = "6, 0, 6, 5"
    $tlPanel.RowCount = 2
    $tlPanel.RowStyles.Add((
            New-Object System.Windows.Forms.RowStyle
        )) | Out-Null
    $tlPanel.RowStyles.Add((
            New-Object System.Windows.Forms.RowStyle("Percent", 100.0)
        )) | Out-Null
    if ($height) {
        $tlPanel.Height = $height
    }

    # $tlPanel.BackColor = "#ff00ff"

    $tlPanel
}

function NewBottomPanel {
    param (
        $height
    )
    $tlPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $tlPanel.AutoSize = $true
    $tlPanel.ColumnCount = 3
    $tlPanel.ColumnStyles.Add((
            New-Object System.Windows.Forms.ColumnStyle
        )) | Out-Null
    $tlPanel.ColumnStyles.Add((
            New-Object System.Windows.Forms.ColumnStyle("Percent", 100.0)
        )) | Out-Null
    $tlPanel.ColumnStyles.Add((
            New-Object System.Windows.Forms.ColumnStyle
        )) | Out-Null
    $tlPanel.Dock = "Bottom"
    $tlPanel.Padding = "15, 12, 15, 12"
    if ($height) {
        $tlPanel.Height = $height
    }

    # $tlPanel.BackColor = "#ff0000"

    $tlPanel
}

function NewButton ($text, $width, $height, $anchor, $dock, $margin, [switch]$autosize, $font) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $text
    if ($autosize) {
        $button.AutoSize = $true
    }
    if ($width) {
        $button.Width = $width
    }
    if ($height) {
        $button.Height = $height
    }
    if ($anchor) {
        $button.Anchor = $anchor
    }
    if ($dock) {
        $button.Dock = $dock
    }
    if ($margin) {
        $button.Margin = $margin
    }
    if ($font) {
        $button.Font = $font
    }
    # $button.UseVisualStyleBackColor = $true
    $button
}

function NewLabel {
    param (
        [string]$text,
        [switch]$location,
        [int]$x,
        [int]$y,
        [switch]$autosize
    )
    $label = New-Object system.Windows.Forms.Label
    $label.Text = $text
    if ($autosize) {
        $label.AutoSize = $true
    }
    else {
        $label.AutoSize = $false
    }
    if ($location) {

        $label.Location = New-Object System.Drawing.Point($x, $y)
    }
    $label
}

function NewProgressBar {
    $ProgressBar = New-Object System.Windows.Forms.ProgressBar
    $ProgressBar.Style = "Marquee"
    $ProgressBar.Dock = "Top"
    # $ProgressBar.Enabled = $false
    $ProgressBar.Visible = $false
    $ProgressBar.MarqueeAnimationSpeed = 17
    $ProgressBar
}

function ListView_OnResize {
    if ($null -ne $this.Parent) {
        UpdateTileSize $this
    }
}

function Get-AllControls {
    param (
        [System.Windows.Forms.Control]$Container,
        [type]$ControlType
    )

    $results = @()

    foreach ($control in $Container.Controls) {
        # Check if the control matches the requested type
        if ($control -is $ControlType) {
            $results += $control
        }
        # If the control has child controls, search deeper
        if ($control.Controls.Count -gt 0) {
            $results += Get-AllControls -Container $control -ControlType $ControlType
        }
    }

    return $results
}

function MainForm_OnResize {
    if ($this.WindowState -eq [System.Windows.Forms.FormWindowState]::Maximized) {
        $ListView = @(Get-AllControls -Container $this -ControlType ([System.Windows.Forms.ListView]))[0]
        $originalWidth = $ListView.Width
        $ListView.Width = $originalWidth - 1
        $ListView.Width = $originalWidth
    }
}

function UpdateTileSize {
    param ($LV)
    if ($Config -and $Config.RowHeight) {
        $rowHeight = $Config.RowHeight
    }
    else {
        $rowHeight = 100
    }
    $availableWidth = $LV.ClientSize.Width - 5
    if ($availableWidth -gt 100) {
        $LV.TileSize = New-Object System.Drawing.Size($availableWidth, $rowHeight)
    }
}

function NewListView {
    $ListView = New-Object System.Windows.Forms.ListView
    $ListView.Dock = "Fill"
    $ListView.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    # $ListView.BackColor = "#2d2d2d"
    # $ListView.ForeColor = "#f0f0f0"
    $ListView.CheckBoxes = $false
    $ListView.View = "Tile"
    # $ListView.TileSize = New-Object System.Drawing.Size(500, 90)
    $ListView.FullRowSelect = $true
    $ListView.Columns.Add("Name"        , -2) | Out-Null
    $ListView.Columns.Add("Id"          , -2, [System.Windows.Forms.HorizontalAlignment]::Right) | Out-Null
    $ListView.Columns.Add("Version"     , -2, [System.Windows.Forms.HorizontalAlignment]::Right) | Out-Null
    $ListView.Columns.Add("Available"   , -2, [System.Windows.Forms.HorizontalAlignment]::Right) | Out-Null
    $ListView.Add_Resize({ ListView_OnResize })
    $ListView
}

function NewListViewItem {
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Explore", "Installed", "Update")]
        [string]$type,
        [Parameter(Mandatory)]
        $package,
        $installedPackages,
        $packageDetails,
        [switch]$icon
    )
    # Column 0 : Name
    $Item = New-Object System.Windows.Forms.ListViewItem($package.Name)
    $Item.Tag = $package
    $Item.UseItemStyleForSubItems = $false
    $Item.SubItems[0].Name = "Name"
    $Item.SubItems[0].Tag = $package.Name
    $Item.SubItems[0].Font = New-Object System.Drawing.Font($Item.SubItems[0].Font, [System.Drawing.FontStyle]::Bold)

    if ($icon) {
        $iconIndex = $reverse_icon_map[$package.Id]
        if (! $iconIndex) {
            $packageDetail = $packageDetails | Where-Object Name -EQ $package.Name | Select-Object -First 1
            if ($packageDetail) {
                $alternativeId = ($packageDetail).Id
                $iconIndex = $reverse_icon_map[$alternativeId]
            }
        }
        $Item.ImageIndex = $iconIndex
    }

    # Column 1 : Id
    $Item.SubItems.Add($package.Id) | Out-Null
    $Item.SubItems[1].Name = "Id"
    $Item.SubItems[1].Tag = $package.Id
    if ("Explore" -eq $type) {
        # Column 2 : Version (Latest)
        $Item.SubItems.Add("Available: $($package.Version)") | Out-Null
        $Item.SubItems[2].Name = "Available"
        $Item.SubItems[2].Tag = $package.Version
        # Column 3 : Source
        $Item.SubItems.Add("Source: $($package.Source)") | Out-Null
        $Item.SubItems[3].Name = "Source"
        $Item.SubItems[3].Tag = $package.Source

        if ((IsInstalled $package $installedPackages )) {
            $Item.ForeColor = [System.Drawing.SystemColors]::ActiveCaption
        }

    }
    if (("Installed" -eq $type) -or ("Update" -eq $type)) {
        # Column 2 : Version (Installed)
        $Item.SubItems.Add("Version: $($package.InstalledVersion)") | Out-Null
        $Item.SubItems[2].Name = "Version"
        $Item.SubItems[2].Tag = $package.InstalledVersion
        #Column 3 : Last Available Version
        if ($package.AvailableVersions.Count -gt 0) {
            $Item.SubItems.Add("Available: $($package.AvailableVersions[0])") | Out-Null
            $Item.SubItems[3].Tag = $package.AvailableVersions[0]
        }
        else {
            $Item.SubItems.Add("") | Out-Null
            $Item.SubItems[3].Tag = ""
        }
        $Item.SubItems[3].Name = "Available"
        # Column 4 : Source
        if ($package.Source) {
            $Item.SubItems.Add("Source: $($package.Source)") | Out-Null
            $Item.SubItems[4].Name = "Source"
            $Item.SubItems[4].Tag = $package.Source
        }
    }
    $Item.SubItems | Where-Object Name -NE "Name" | ForEach-Object { $_.ForeColor = [System.Drawing.SystemColors]::InfoText }

    $Item
}

function NewTextBox ($dock, $anchor, $width, $padding, $margin) {
    $textBox = New-Object System.Windows.Forms.TextBox
    # $textBox.BorderStyle = 'FixedSingle'
    if ($dock) {
        $textBox.Dock = $dock
    }
    if ($anchor) {
        $textBox.Anchor = $anchor
    }
    if ($width) {
        $textBox.Width = $width
    }
    if ($margin) {
        $textBox.Margin = $margin
    }
    $textBox
}

function NewComboBox ($items) {
    $comboBox = New-Object Windows.Forms.ComboBox
    $comboBox.Dock = "Top"
    $comboBox.Padding = "3, 3, 6, 3"
    $comboBox.Items.AddRange($items)
    $comboBox
}

function NewCheckbox {
    param (
        $threeState = $false,
        $text,
        $margin
    )
    $checkBox = New-Object System.Windows.Forms.CheckBox
    $checkBox.ThreeState = $threeState
    $checkBox.Text = $text
    if ($margin) {
        $checkBox.Margin = $margin
    }
    $checkBox
}