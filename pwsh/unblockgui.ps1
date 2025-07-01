# ZoneIdManager.ps1

# ── Load WinForms & Enable Visual Styles ─────────────────────────────────
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# ── Create Main Form ─────────────────────────────────────────────────────
$form = [System.Windows.Forms.Form]@{
    Text            = "Zone.Identifier Manager"
    Size            = [System.Drawing.Size]::new(1200,1000)
    StartPosition   = 'CenterScreen'
    FormBorderStyle = 'FixedDialog'
    MaximizeBox     = $false
}

# ── Folder Selection Controls ─────────────────────────────────────────────
$txtFolder = [System.Windows.Forms.TextBox]@{
    Location = [System.Drawing.Point]::new(10,10)
    Size     = [System.Drawing.Size]::new(450,20)
    ReadOnly = $true
}
$form.Controls.Add($txtFolder)
# ── Status Bar ────────────────────────────────────────────────────────────
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusLabel  = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Ready"
$statusStrip.Items.Add($statusLabel)
$form.Controls.Add($statusStrip)

$btnBrowse = [System.Windows.Forms.Button]@{
    Text     = "Browse…"
    Location = [System.Drawing.Point]::new(470,8)
    Size     = [System.Drawing.Size]::new(100,24)
}
$form.Controls.Add($btnBrowse)

# ── Results List ─────────────────────────────────────────────────────────
$listBox = [System.Windows.Forms.ListBox]@{
    Location = [System.Drawing.Point]::new(10,50)
    Size     = [System.Drawing.Size]::new(1000,800)
}
$form.Controls.Add($listBox)

# ── Action Buttons ───────────────────────────────────────────────────────
$btnScan = [System.Windows.Forms.Button]@{
    Text     = "Scan"
    Location = [System.Drawing.Point]::new(650,8)
    Size     = [System.Drawing.Size]::new(100,30)
}
$form.Controls.Add($btnScan)

$btnUnblock = [System.Windows.Forms.Button]@{
    Text     = "Unblock All"
    Location = [System.Drawing.Point]::new(790,8)
    Size     = [System.Drawing.Size]::new(100,30)
}
$form.Controls.Add($btnUnblock)

# ── Browse Folder Event ─────────────────────────────────────────────────
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Select folder to scan"
    if ($dlg.ShowDialog() -eq 'OK') {
        $txtFolder.Text = $dlg.SelectedPath
        $listBox.Items.Clear()
    }
})

# ── Scan for Blocked Files Event ─────────────────────────────────────────
# Scan button
$btnScan.Add_Click({
    $statusLabel.Text = "Scanning…"
    [System.Windows.Forms.Application]::DoEvents()

    $listBox.Items.Clear()
    Get-ChildItem -Path $txtFolder.Text -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        if (Get-Item $_.FullName -Stream "Zone.Identifier" -ErrorAction SilentlyContinue) {
            $listBox.Items.Add($_.FullName)
        }
    }

    $statusLabel.Text = "Scan complete: $($listBox.Items.Count) files found."
})

# Unblock All button
$btnUnblock.Add_Click({
    $statusLabel.Text = "Unblocking…"
    [System.Windows.Forms.Application]::DoEvents()

    $count = 0
    foreach ($path in $listBox.Items) {
        try {
            Unblock-File -Path $path -ErrorAction Stop
            $count++
        } catch {}
    }

    $listBox.Items.Clear()
    $statusLabel.Text = "Unblocked $count files."
})

# ── Start the GUI ─────────────────────────────────────────────────────────
[System.Windows.Forms.Application]::Run($form)
