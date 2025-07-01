# File Explorer GUI Script
# PowerShell script with Windows Forms GUI for file exploration

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "File Explorer GUI"
$form.Size = New-Object System.Drawing.Size(1000, 760)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(800, 660)

# Create folder selection controls
$folderLabel = New-Object System.Windows.Forms.Label
$folderLabel.Location = New-Object System.Drawing.Point(10, 10)
$folderLabel.Size = New-Object System.Drawing.Size(100, 23)
$folderLabel.Text = "Selected Folder:"
$form.Controls.Add($folderLabel)

$folderTextBox = New-Object System.Windows.Forms.TextBox
$folderTextBox.Location = New-Object System.Drawing.Point(120, 10)
$folderTextBox.Size = New-Object System.Drawing.Size(500, 23)
$folderTextBox.ReadOnly = $false
$form.Controls.Add($folderTextBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Location = New-Object System.Drawing.Point(630, 9)
$browseButton.Size = New-Object System.Drawing.Size(75, 25)
$browseButton.Text = "Browse"
$form.Controls.Add($browseButton)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Location = New-Object System.Drawing.Point(715, 9)
$refreshButton.Size = New-Object System.Drawing.Size(75, 25)
$refreshButton.Text = "Refresh"
$form.Controls.Add($refreshButton)

# Create filter controls
$filterLabel = New-Object System.Windows.Forms.Label
$filterLabel.Location = New-Object System.Drawing.Point(10, 45)
$filterLabel.Size = New-Object System.Drawing.Size(100, 23)
$filterLabel.Text = "Filter Extensions:"
$form.Controls.Add($filterLabel)

$filterTextBox = New-Object System.Windows.Forms.TextBox
$filterTextBox.Location = New-Object System.Drawing.Point(120, 45)
$filterTextBox.Size = New-Object System.Drawing.Size(200, 23)
$filterTextBox.Text = "*.* (All files)"
$form.Controls.Add($filterTextBox)

$filterButton = New-Object System.Windows.Forms.Button
$filterButton.Location = New-Object System.Drawing.Point(330, 44)
$filterButton.Size = New-Object System.Drawing.Size(75, 25)
$filterButton.Text = "Apply Filter"
$form.Controls.Add($filterButton)

$clearFilterButton = New-Object System.Windows.Forms.Button
$clearFilterButton.Location = New-Object System.Drawing.Point(415, 44)
$clearFilterButton.Size = New-Object System.Drawing.Size(75, 25)
$clearFilterButton.Text = "Clear Filter"
$form.Controls.Add($clearFilterButton)

# Checkbox for filtering files without description
$hideNoDescCheckBox = New-Object System.Windows.Forms.CheckBox
$hideNoDescCheckBox.Location = New-Object System.Drawing.Point(500, 47)
$hideNoDescCheckBox.Size = New-Object System.Drawing.Size(180, 23)
$hideNoDescCheckBox.Text = "Hide files without description"
$form.Controls.Add($hideNoDescCheckBox)

# Recursive search checkbox
$recursiveCheckBox = New-Object System.Windows.Forms.CheckBox
$recursiveCheckBox.Location = New-Object System.Drawing.Point(690, 47)
$recursiveCheckBox.Size = New-Object System.Drawing.Size(100, 23)
$recursiveCheckBox.Text = "Recursive"
$form.Controls.Add($recursiveCheckBox)

# Command line arguments section
$cmdArgsCheckBox = New-Object System.Windows.Forms.CheckBox
$cmdArgsCheckBox.Location = New-Object System.Drawing.Point(10, 80)
$cmdArgsCheckBox.Size = New-Object System.Drawing.Size(150, 23)
$cmdArgsCheckBox.Text = "Use command line args:"
$form.Controls.Add($cmdArgsCheckBox)

$cmdArgsTextBox = New-Object System.Windows.Forms.TextBox
$cmdArgsTextBox.Location = New-Object System.Drawing.Point(170, 80)
$cmdArgsTextBox.Size = New-Object System.Drawing.Size(800, 23)
$cmdArgsTextBox.Enabled = $false
$cmdArgsTextBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($cmdArgsTextBox)

# Create ListView for file display
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(10, 110)
$listView.Size = New-Object System.Drawing.Size(960, 420)
$listView.View = [System.Windows.Forms.View]::Details
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.MultiSelect = $false
$listView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

# Add columns
$listView.Columns.Add("Name", 200) | Out-Null
$listView.Columns.Add("Extension", 80) | Out-Null
$listView.Columns.Add("Type", 150) | Out-Null
$listView.Columns.Add("Size", 100) | Out-Null
$listView.Columns.Add("File Description", 300) | Out-Null

$form.Controls.Add($listView)

# Create action buttons
$runButton = New-Object System.Windows.Forms.Button
$runButton.Location = New-Object System.Drawing.Point(10, 540)
$runButton.Size = New-Object System.Drawing.Size(100, 30)
$runButton.Text = "Run Selected"
$runButton.Enabled = $false
$runButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($runButton)

$propertiesButton = New-Object System.Windows.Forms.Button
$propertiesButton.Location = New-Object System.Drawing.Point(120, 540)
$propertiesButton.Size = New-Object System.Drawing.Size(100, 30)
$propertiesButton.Text = "Properties"
$propertiesButton.Enabled = $false
$propertiesButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($propertiesButton)

# File count label
$fileCountLabel = New-Object System.Windows.Forms.Label
$fileCountLabel.Location = New-Object System.Drawing.Point(770, 545)
$fileCountLabel.Size = New-Object System.Drawing.Size(200, 23)
$fileCountLabel.Text = "Files: 0"
$fileCountLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$fileCountLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($fileCountLabel)

# Command line display section
$cmdLineLabel = New-Object System.Windows.Forms.Label
$cmdLineLabel.Location = New-Object System.Drawing.Point(10, 575)
$cmdLineLabel.Size = New-Object System.Drawing.Size(100, 23)
$cmdLineLabel.Text = "Command Line:"
$cmdLineLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($cmdLineLabel)

$cmdLineTextBox = New-Object System.Windows.Forms.TextBox
$cmdLineTextBox.Location = New-Object System.Drawing.Point(120, 575)
$cmdLineTextBox.Size = New-Object System.Drawing.Size(850, 23)
$cmdLineTextBox.ReadOnly = $true
$cmdLineTextBox.BackColor = [System.Drawing.Color]::LightGray
$cmdLineTextBox.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($cmdLineTextBox)

# Create progress bar and status at bottom
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 605)
$progressBar.Size = New-Object System.Drawing.Size(960, 20)
$progressBar.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$progressBar.Visible = $false
$form.Controls.Add($progressBar)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 630)
$statusLabel.Size = New-Object System.Drawing.Size(960, 23)
$statusLabel.Text = "Ready - Select a folder to begin"
$statusLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($statusLabel)

# Function to update command line display
function Update-CommandLineDisplay {
    if ($listView.SelectedItems.Count -gt 0) {
        $selectedFile = $listView.SelectedItems[0].Tag
        
        if ($cmdArgsCheckBox.Checked -and ![string]::IsNullOrWhiteSpace($cmdArgsTextBox.Text)) {
            $cmdLineTextBox.Text = "`"$selectedFile`" $($cmdArgsTextBox.Text)"
        } else {
            $cmdLineTextBox.Text = "`"$selectedFile`""
        }
    } else {
        $cmdLineTextBox.Text = ""
    }
}

# Global variables
$currentFolder = ""
$allFiles = @()

# Function to get correct file description
function Get-FileDescription {
    param([string]$FilePath)
    
    try {
        # Use .NET FileVersionInfo which gets the actual "File description" property
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath)
        if (![string]::IsNullOrWhiteSpace($versionInfo.FileDescription)) {
            return $versionInfo.FileDescription
        }
        
        # Fallback to Shell COM object for non-executable files
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace((Get-Item $FilePath).DirectoryName)
        $file = $folder.ParseName((Get-Item $FilePath).Name)
        
        # Try different indices for file description
        for ($i = 0; $i -lt 50; $i++) {
            $detail = $folder.GetDetailsOf($file, $i)
            $header = $folder.GetDetailsOf($null, $i)
            if ($header -eq "File description" -and ![string]::IsNullOrWhiteSpace($detail)) {
                return $detail
            }
        }
        
        return ""
    }
    catch {
        return ""
    }
}

# Function to format file size
function Format-FileSize {
    param([long]$Size)
    
    if ($Size -eq 0) { return "0 B" }
    
    $units = @("B", "KB", "MB", "GB", "TB")
    $index = 0
    $sizeDouble = [double]$Size
    
    while ($sizeDouble -ge 1024 -and $index -lt $units.Length - 1) {
        $sizeDouble /= 1024
        $index++
    }
    
    return "{0:N2} {1}" -f $sizeDouble, $units[$index]
}

# Function to load files with progress bar
function Load-Files {
    param(
        [string]$FolderPath,
        [string]$Filter = "*.*",
        [bool]$HideNoDescription = $false,
        [bool]$Recursive = $false
    )
    
    if (![System.IO.Directory]::Exists($FolderPath)) {
        $statusLabel.Text = "Error: Folder does not exist"
        return
    }
    
    $listView.Items.Clear()
    $progressBar.Visible = $true
    $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
    $statusLabel.Text = "Scanning folder..."
    $form.Update()
    
    try {
        # Parse filter - support multiple extensions separated by semicolon
        $filterPatterns = @()
        if ($Filter -eq "*.*" -or $Filter -eq "*.* (All files)" -or [string]::IsNullOrWhiteSpace($Filter)) {
            $filterPatterns = @("*.*")
        }
        else {
            $filterPatterns = $Filter -split ';' | ForEach-Object { $_.Trim() }
        }
        
        $files = @()
        foreach ($pattern in $filterPatterns) {
            if (![string]::IsNullOrWhiteSpace($pattern)) {
                if ($Recursive) {
                    $files += Get-ChildItem -Path $FolderPath -Filter $pattern -File -Recurse -ErrorAction SilentlyContinue
                } else {
                    $files += Get-ChildItem -Path $FolderPath -Filter $pattern -File -ErrorAction SilentlyContinue
                }
            }
        }
        
        # Remove duplicates
        $files = $files | Sort-Object FullName | Get-Unique -AsString
        
        if ($files.Count -eq 0) {
            $progressBar.Visible = $false
            $statusLabel.Text = "No files found matching the filter"
            $fileCountLabel.Text = "Files: 0"
            return
        }
        
        # Switch to blocks style for actual progress
        $progressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Blocks
        $progressBar.Minimum = 0
        $progressBar.Maximum = $files.Count
        $progressBar.Value = 0
        
        $global:allFiles = @()
        $processedCount = 0
        
        foreach ($file in $files) {
            $processedCount++
            $progressBar.Value = $processedCount
            
            # Update status every 5 files to avoid too frequent updates
            if ($processedCount % 5 -eq 0 -or $processedCount -eq $files.Count) {
                $statusLabel.Text = "Processing file $processedCount of $($files.Count): $($file.Name)"
                $form.Update()
            }
            
            $description = Get-FileDescription -FilePath $file.FullName
            
            # Skip files without description if filter is enabled
            if ($HideNoDescription -and [string]::IsNullOrWhiteSpace($description)) {
                continue
            }
            
            $fileInfo = [PSCustomObject]@{
                Name = $file.Name
                Extension = $file.Extension
                Type = if (![string]::IsNullOrWhiteSpace($file.Extension)) { 
                    "$($file.Extension.TrimStart('.').ToUpper()) File" 
                } else { "File" }
                Size = $file.Length
                SizeFormatted = Format-FileSize -Size $file.Length
                Description = $description
                FullPath = $file.FullName
            }
            
            $global:allFiles += $fileInfo
        }
        
        # Add items to ListView
        $statusLabel.Text = "Adding items to display..."
        $form.Update()
        
        foreach ($fileInfo in $global:allFiles) {
            $item = New-Object System.Windows.Forms.ListViewItem($fileInfo.Name)
            $item.SubItems.Add($fileInfo.Extension) | Out-Null
            $item.SubItems.Add($fileInfo.Type) | Out-Null
            $item.SubItems.Add($fileInfo.SizeFormatted) | Out-Null
            $item.SubItems.Add($fileInfo.Description) | Out-Null
            $item.Tag = $fileInfo.FullPath
            
            $listView.Items.Add($item) | Out-Null
        }
        
        $progressBar.Visible = $false
        $fileCountLabel.Text = "Files: $($global:allFiles.Count)"
        $statusLabel.Text = "Loaded $($global:allFiles.Count) files successfully"
    }
    catch {
        $progressBar.Visible = $false
        $statusLabel.Text = "Error loading files: $($_.Exception.Message)"
    }
}

# Event handlers
$browseButton.Add_Click({
    try {
        $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderDialog.Description = "Select a folder to explore"
        $folderDialog.ShowNewFolderButton = $false
        
        if (![string]::IsNullOrWhiteSpace($folderTextBox.Text) -and [System.IO.Directory]::Exists($folderTextBox.Text)) {
            $folderDialog.SelectedPath = $folderTextBox.Text
        }
        
        if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $global:currentFolder = $folderDialog.SelectedPath
            $folderTextBox.Text = $global:currentFolder
            
            $filter = if ($filterTextBox.Text -eq "*.* (All files)") { "*.*" } else { $filterTextBox.Text }
            Load-Files -FolderPath $global:currentFolder -Filter $filter -HideNoDescription $hideNoDescCheckBox.Checked -Recursive $recursiveCheckBox.Checked
        }
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Error selecting folder: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Handle manual folder text entry
$folderTextBox.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $folderPath = $folderTextBox.Text.Trim()
        if ([System.IO.Directory]::Exists($folderPath)) {
            $global:currentFolder = $folderPath
            $filter = if ($filterTextBox.Text -eq "*.* (All files)") { "*.*" } else { $filterTextBox.Text }
            Load-Files -FolderPath $global:currentFolder -Filter $filter -HideNoDescription $hideNoDescCheckBox.Checked -Recursive $recursiveCheckBox.Checked
        } else {
            $statusLabel.Text = "Error: Invalid folder path"
        }
    }
})

$refreshButton.Add_Click({
    $folderPath = $folderTextBox.Text.Trim()
    if ([System.IO.Directory]::Exists($folderPath)) {
        $global:currentFolder = $folderPath
        $filter = if ($filterTextBox.Text -eq "*.* (All files)") { "*.*" } else { $filterTextBox.Text }
        Load-Files -FolderPath $global:currentFolder -Filter $filter -HideNoDescription $hideNoDescCheckBox.Checked -Recursive $recursiveCheckBox.Checked
    } else {
        $statusLabel.Text = "Error: Invalid folder path"
    }
})

$filterButton.Add_Click({
    if (![string]::IsNullOrWhiteSpace($global:currentFolder)) {
        $filter = if ($filterTextBox.Text -eq "*.* (All files)") { "*.*" } else { $filterTextBox.Text }
        Load-Files -FolderPath $global:currentFolder -Filter $filter -HideNoDescription $hideNoDescCheckBox.Checked -Recursive $recursiveCheckBox.Checked
    }
})

$clearFilterButton.Add_Click({
    $filterTextBox.Text = "*.* (All files)"
    if (![string]::IsNullOrWhiteSpace($global:currentFolder)) {
        Load-Files -FolderPath $global:currentFolder -Filter "*.*" -HideNoDescription $hideNoDescCheckBox.Checked -Recursive $recursiveCheckBox.Checked
    }
})

$hideNoDescCheckBox.Add_CheckedChanged({
    if (![string]::IsNullOrWhiteSpace($global:currentFolder)) {
        $filter = if ($filterTextBox.Text -eq "*.* (All files)") { "*.*" } else { $filterTextBox.Text }
        Load-Files -FolderPath $global:currentFolder -Filter $filter -HideNoDescription $hideNoDescCheckBox.Checked -Recursive $recursiveCheckBox.Checked
    }
})

$recursiveCheckBox.Add_CheckedChanged({
    if (![string]::IsNullOrWhiteSpace($global:currentFolder)) {
        $filter = if ($filterTextBox.Text -eq "*.* (All files)") { "*.*" } else { $filterTextBox.Text }
        Load-Files -FolderPath $global:currentFolder -Filter $filter -HideNoDescription $hideNoDescCheckBox.Checked -Recursive $recursiveCheckBox.Checked
    }
})

# Command line arguments event handlers
$cmdArgsCheckBox.Add_CheckedChanged({
    $cmdArgsTextBox.Enabled = $cmdArgsCheckBox.Checked
    if (!$cmdArgsCheckBox.Checked) {
        $cmdArgsTextBox.Text = ""
    }
    Update-CommandLineDisplay
})

$cmdArgsTextBox.Add_TextChanged({
    Update-CommandLineDisplay
})

$hideNoDescCheckBox.Add_CheckedChanged({
    if (![string]::IsNullOrWhiteSpace($global:currentFolder)) {
        $filter = if ($filterTextBox.Text -eq "*.* (All files)") { "*.*" } else { $filterTextBox.Text }
        Load-Files -FolderPath $global:currentFolder -Filter $filter -HideNoDescription $hideNoDescCheckBox.Checked
    }
})

$listView.Add_SelectedIndexChanged({
    $runButton.Enabled = $listView.SelectedItems.Count -gt 0
    $propertiesButton.Enabled = $listView.SelectedItems.Count -gt 0
    Update-CommandLineDisplay
})

$listView.Add_DoubleClick({
    if ($listView.SelectedItems.Count -gt 0) {
        $selectedFile = $listView.SelectedItems[0].Tag
        try {
            if ($cmdArgsCheckBox.Checked -and ![string]::IsNullOrWhiteSpace($cmdArgsTextBox.Text)) {
                Start-Process -FilePath $selectedFile -ArgumentList $cmdArgsTextBox.Text -ErrorAction Stop
                $statusLabel.Text = "Launched: $(Split-Path $selectedFile -Leaf) with arguments: $($cmdArgsTextBox.Text)"
            } else {
                Start-Process -FilePath $selectedFile -ErrorAction Stop
                $statusLabel.Text = "Launched: $(Split-Path $selectedFile -Leaf)"
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Cannot run file: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

$runButton.Add_Click({
    if ($listView.SelectedItems.Count -gt 0) {
        $selectedFile = $listView.SelectedItems[0].Tag
        try {
            if ($cmdArgsCheckBox.Checked -and ![string]::IsNullOrWhiteSpace($cmdArgsTextBox.Text)) {
                Start-Process -FilePath $selectedFile -ArgumentList $cmdArgsTextBox.Text -ErrorAction Stop
                $statusLabel.Text = "Launched: $(Split-Path $selectedFile -Leaf) with arguments: $($cmdArgsTextBox.Text)"
            } else {
                Start-Process -FilePath $selectedFile -ErrorAction Stop
                $statusLabel.Text = "Launched: $(Split-Path $selectedFile -Leaf)"
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Cannot run file: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

$propertiesButton.Add_Click({
    if ($listView.SelectedItems.Count -gt 0) {
        $selectedFile = $listView.SelectedItems[0].Tag
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "explorer.exe"
            $psi.Arguments = "/select,`"$selectedFile`""
            $psi.UseShellExecute = $true
            [System.Diagnostics.Process]::Start($psi) | Out-Null
            $statusLabel.Text = "Opened properties for: $(Split-Path $selectedFile -Leaf)"
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("Cannot open properties: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    }
})

# Enable column sorting
$listView.Add_ColumnClick({
    param($sender, $e)
    
    # Simple sorting by converting ListView to array and back
    $items = @()
    foreach ($item in $listView.Items) {
        $items += $item
    }
    
    # Sort based on column
    switch ($e.Column) {
        0 { $items = $items | Sort-Object { $_.Text } }  # Name
        1 { $items = $items | Sort-Object { $_.SubItems[1].Text } }  # Extension
        2 { $items = $items | Sort-Object { $_.SubItems[2].Text } }  # Type
        3 { 
            # Sort by actual file size, not formatted string
            $items = $items | Sort-Object { 
                $fileInfo = $global:allFiles | Where-Object { $_.FullPath -eq $_.Tag }
                if ($fileInfo) { $fileInfo.Size } else { 0 }
            }
        }
        4 { $items = $items | Sort-Object { $_.SubItems[4].Text } }  # File Description
    }
    
    $listView.Items.Clear()
    foreach ($item in $items) {
        $listView.Items.Add($item) | Out-Null
    }
})

# Add tooltips
$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.SetToolTip($filterTextBox, "Enter file extensions separated by semicolons (e.g., *.exe;*.dll;*.txt) or *.* for all files")
$toolTip.SetToolTip($recursiveCheckBox, "Search in subfolders recursively")
$toolTip.SetToolTip($cmdArgsCheckBox, "Enable command line arguments for running files")
$toolTip.SetToolTip($cmdArgsTextBox, "Enter command line arguments to pass to the selected file")
$toolTip.SetToolTip($cmdLineTextBox, "Complete command line - click to select all text for copying")

# Add click event to command line textbox for easy copying
$cmdLineTextBox.Add_Click({
    if (![string]::IsNullOrWhiteSpace($cmdLineTextBox.Text)) {
        $cmdLineTextBox.SelectAll()
    }
})

# Show form
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()