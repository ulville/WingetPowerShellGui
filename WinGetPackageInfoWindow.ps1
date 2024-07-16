function Show-WinGetPackageInfoWindow {
    param (
        [Alias("q")]
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Query,
        [switch]$Id,
        [switch]$Name,
        [switch]$Moniker,
        [string]$Version
    )
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $WinGetPSGUIDataDir = "$env:APPDATA\WinGetPowerShellGui\"
    $PackageInfosDir = "$WinGetPSGUIDataDir\PackageInfos\"
    if (-not (Test-Path -Path $PackageInfosDir -PathType Container)) {
        Write-Host PackageInfos Path Not Exists
        New-Item -Path $PackageInfosDir -ItemType Directory
    }


    [Windows.Forms.Application]::EnableVisualStyles()

    # Info Window
    $InfoWindow = New-Object System.Windows.Forms.Form
    $InfoWindow.ClientSize = '1000,900'
    $InfoWindow.StartPosition = "CenterScreen"
    $InfoWindow.Padding = New-Object System.Windows.Forms.Padding(0, 12, 0, 12)
    $InfoWindow.BackColor = "#fbfbfb" # [System.Drawing.SystemColors]::ControlLightLight
    $InfoWindow.Add_Shown({ InfoWindow_OnShown })

    # Spinner
    $Spinner = New-Object System.Windows.Forms.PictureBox
    $Spinner.ImageLocation = "$PSScriptRoot\spinner.gif"
    $Spinner.AutoSize = $true
    $Spinner.Anchor = "None"
    $Spinner.Location = New-Object System.Drawing.Point(
        [int](($InfoWindow.ClientSize.Width - $Spinner.Size.Width) / 2),
        [int](($InfoWindow.ClientSize.Height - $Spinner.Size.Height) / 2)
    );
    # $Spinner.Dock = "Fill"
    $InfoWindow.Controls.Add($Spinner)

    # Info Panel
    $InfoPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $InfoPanel.Padding = New-Object System.Windows.Forms.Padding(60, 0, 60, 0)
    $InfoPanel.Dock = "Fill"
    $InfoPanel.AutoScroll = "True"
    $InfoPanel.ColumnCount = 2
    $InfoPanel.ColumnStyles.Add((
            New-Object System.Windows.Forms.ColumnStyle
        )) | Out-Null
    $InfoPanel.ColumnStyles.Add((
            New-Object System.Windows.Forms.ColumnStyle("Percent", 100.0)
        )) | Out-Null

    $InfoWindow.Controls.Add($InfoPanel)

    function DisplayHeader {
        param (
            $Text, $Level
        )
        $header = New-Object System.Windows.Forms.Label
        $header.Margin = 3
        $StyledText = $Text
        $fontsize = 10.5
        # $bgcolor = "#ffdddd"
        if ($Level -gt 0) {
            $mrgn = $header.Margin
            $mrgn.Left += 6 * $Level
            $header.Margin = $mrgn
            $StyledText = "• $Text"
            $fontsize = 9.5
            # $bgcolor = "#ff44ff"
        }
        $header.Text = $StyledText
        $header.AutoSize = $true
        $header.Font = New-Object System.Drawing.Font('Segoe UI', $fontsize)
        if ($Level -gt 1) {
            $header.Font = New-Object System.Drawing.Font(
                'Segoe UI', $fontsize, [System.Drawing.FontStyle]::Italic)
        }
        # $header.BackColor = $bgcolor
        $tt = New-Object System.Windows.Forms.ToolTip
        $tt.SetToolTip($header, $Text)
        $InfoPanel.Controls.Add($header)
        $header
    }
    
    function DisplayLabelOrLink {
        param (
            $Key, $Text, $Level
        )
        
        $Text = [string]$Text
        if ($Text.StartsWith("http")) {
            $control = New-Object System.Windows.Forms.LinkLabel
            $control.Add_LinkClicked({ OnLinkClicked })
            $control.AutoSize = $true
            # $control.Height = 30
            $control.Text = $Text
        }
        else {
            $control = New-Object System.Windows.Forms.Label
            $control.AutoSize = $true
            $control.Text = $Text
        }
        $control.Margin = 3
        $control.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)
        # $control.BackColor = "#ddffff"
        $control.ForeColor = [System.Drawing.SystemColors]::GrayText
        $InfoPanel.Controls.Add($control)
        $control
    }
    
    function DisplayMultiDimentionDict {
        param (
            $Dictionary, $Level
        )
        foreach ($key in $Dictionary.Keys) {
            DisplayHeader -Text $key -Level $Level
            # if ($key -eq "Dependencies") {
            #     $debvar = $Dictionary.$key.GetType()
            # }
            if ($Dictionary.$key.GetType().Name -eq "OrderedDictionary") {
                $InfoPanel.Controls.Add((New-Object System.Windows.Forms.Label))
                DisplayMultiDimentionDict -Dictionary $Dictionary.$key -Level ($Level + 1)
            }
            elseif ($Dictionary.$key.GetType().Name -eq "ArrayList") {
                foreach ($item in $Dictionary.$key) {
                    $InfoPanel.Controls.Add((New-Object System.Windows.Forms.Label))
                    DisplayMultiDimentionDict -Dictionary $Dictionary.$key -Level ($Level + 1)
                }
            }
            else {
                DisplayLabelOrLink -Key $key -Text $Dictionary.$key -Level $Level
            }
        }
    }

    function InfoWindow_OnShown {
    
        # Clear info window
        $InfoPanel.Controls.Clear()

        if (Test-Path -Path $PackageInfosDir) {
            <# Action to perform if the condition is true #>
        }
        


        # Start `winget show` job
        $jobby = Start-Job -ScriptBlock $getPackageInfo -ArgumentList $Query, $Id, $Name, $Moniker
        Do { [System.Windows.Forms.Application]::DoEvents() } Until ($jobby.State -eq "Completed")
        $packageInfo = Get-Job | Receive-Job
        $Spinner.Visible = $false
        $InfoWindow.Controls.Remove($Spinner)
        $Spinner.Dispose()
        
        # Display Multi-Dimention Dictionary
        DisplayMultiDimentionDict -Dictionary $packageInfo -Level 0

        $InfoWindow.Text = "Info: " + $Query
    }

    function OnLinkClicked {
        Start-Process $this.Text
    }

    $getPackageInfo =
    {
        param (
            [string]$Query,
            [bool]$Id,
            [bool]$Name,
            [bool]$Moniker
        )
        Import-Module Ulville.WinGetShow
        # $text = "Query: $Query, Id: $Id, Name: $Name, Moniker: $Moniker"
        # Write-Host $text
        if ($Id) {
            Get-WinGetPackageInformation -Id -Query $Query
        }
        elseif ($Name) {
            Get-WinGetPackageInformation -Name -Query $Query
        }
        elseif ($Moniker) {
            Get-WinGetPackageInformation -Moniker -Query $Query
        }
        else {
            Get-WinGetPackageInformation -Query $Query
        }
    }

    $InfoWindow.ShowDialog()
}