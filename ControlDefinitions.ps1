Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function NewMainForm() {
    $MainForm = New-Object system.Windows.Forms.Form
    $MainForm.ClientSize = '566,550'
    $MainForm.Text = "Ulvican Kahya - Winget Update Gui"
    $MainForm.StartPosition = "CenterScreen"
    # $MainForm.Padding = 12
    $MainForm
}

function NewTabControl() {
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Dock = "Top"
    $tabControl.Height = 124
    $tabControl
}

function NewTabPage ([string]$text) {
    $tabPage = New-Object System.Windows.Forms.TabPage
    $tabPage.Text = $text
    $tabPage.UseVisualStyleBackColor = $true
    $tabPage.Padding = 12
    $tabPage
}

function NewPanel ($dock, $bgcolor, $height) {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = $dock
    $panel.BackColor = $bgcolor
    if ($height) {
        $panel.Height = $height
    }
    $panel
}

function NewButton ($text, $width, $height, $anchor, $dock) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $text
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
    $button
}

function NewLabel {
    param (
        [string]$text,
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
    $label.Location = New-Object System.Drawing.Point($x, $y)
    $label
}

function NewProgressBar {
    $ProgressBar = New-Object System.Windows.Forms.ProgressBar
    $ProgressBar.Style = "Marquee"
    $ProgressBar.Dock = "Bottom"
    $ProgressBar.Enabled = $false
    $ProgressBar.Visible = $false
    $ProgressBar.MarqueeAnimationSpeed = 17
    $ProgressBar
}

function NewListView {
    $ListView = New-Object System.Windows.Forms.ListView
    $ListView.Dock = "Fill"
    $ListView.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $ListView.CheckBoxes = $true
    $ListView.View = "Details"
    $ListView.FullRowSelect = $true
    $ListView.Columns.Add("Id"          , -2) | Out-Null
    $ListView.Columns.Add("Name"        , -2) | Out-Null
    $ListView.Columns.Add("Version"     , -2) | Out-Null
    $ListView.Columns.Add("Available"   , -2) | Out-Null
    $ListView
}

function NewTextBox ($dock, $anchor, $width) {
    $textBox = New-Object System.Windows.Forms.TextBox
    if ($dock) {
        $textBox.Dock = $dock
    }
    if ($anchor) {
        $textBox.Anchor = $anchor
    }
    $textBox.Width = $width
    $textBox.AutoSize = $true
    $textBox
}