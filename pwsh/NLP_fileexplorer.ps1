# File Explorer GUI Script
# PowerShell script with Windows Forms GUI for file exploration

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Initialize global lists for known executables
$global:exeList = @()
$global:exeSectionMap = @{}

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "File Explorer GUI"
$form.Size = New-Object System.Drawing.Size(1000, 800)
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
# ListView columns
$listView.Columns.Add("Name", 200) | Out-Null
$listView.Columns.Add("Section", 150) | Out-Null
$listView.Columns.Add("Extension", 80) | Out-Null
$listView.Columns.Add("Type", 150) | Out-Null
$listView.Columns.Add("Size", 100) | Out-Null
$listView.Columns.Add("File Description", 300) | Out-Null
# --- Add new columns for additional file properties ---
$listView.Columns.Add("Date Created", 120) | Out-Null
$listView.Columns.Add("Date Modified", 120) | Out-Null
$listView.Columns.Add("Date Accessed", 120) | Out-Null
$listView.Columns.Add("Path", 200) | Out-Null
$listView.Columns.Add("Length", 100) | Out-Null

$form.Controls.Add($listView)

# Create export button
$exportButton = New-Object System.Windows.Forms.Button
$exportButton.Location = New-Object System.Drawing.Point(230, 540)
$exportButton.Size = New-Object System.Drawing.Size(100, 30)
$exportButton.Text = "Export CSV"
$exportButton.Enabled = $false
$exportButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($exportButton)

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
# Add Sync Mod Date button
$syncDatesButton = New-Object System.Windows.Forms.Button
$syncDatesButton.Location = New-Object System.Drawing.Point(350, 540)
$syncDatesButton.Size = New-Object System.Drawing.Size(150, 30)
$syncDatesButton.Text = "Sync Mod Date"
$syncDatesButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($syncDatesButton)

# Add Page Swap button
$pageSwapButton = New-Object System.Windows.Forms.Button
$pageSwapButton.Location = New-Object System.Drawing.Point(520, 540)
$pageSwapButton.Size = New-Object System.Drawing.Size(100, 30)
$pageSwapButton.Text = "Page 2"
$pageSwapButton.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($pageSwapButton)

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
$statusLabel.Size = New-Object System.Drawing.Size(960, 150)
$statusLabel.Text = "Ready - Select a folder to begin"
$statusLabel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($statusLabel)

# Create legend labels for Page 2 color coding
$legendLabel1 = New-Object System.Windows.Forms.Label
$legendLabel1.Location = New-Object System.Drawing.Point(10, 650)
$legendLabel1.Size = New-Object System.Drawing.Size(400, 23)
$legendLabel1.Text = "Red = Expected files missing (both missing, or single expected file missing)"
$legendLabel1.ForeColor = [System.Drawing.Color]::Red
$legendLabel1.Visible = $false
$legendLabel1.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($legendLabel1)

$legendLabel2 = New-Object System.Windows.Forms.Label
$legendLabel2.Location = New-Object System.Drawing.Point(10, 670)
$legendLabel2.Size = New-Object System.Drawing.Size(400, 23)
$legendLabel2.Text = "Blue = Both exe and exe64 expected, but only one found"
$legendLabel2.ForeColor = [System.Drawing.Color]::Blue
$legendLabel2.Visible = $false
$legendLabel2.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($legendLabel2)

# Create Page 2 controls (initially hidden)
$page2ListView = New-Object System.Windows.Forms.ListView
$page2ListView.Location = New-Object System.Drawing.Point(10, 110)
$page2ListView.Size = New-Object System.Drawing.Size(960, 420)
$page2ListView.View = [System.Windows.Forms.View]::Details
$page2ListView.FullRowSelect = $true
$page2ListView.GridLines = $true
$page2ListView.MultiSelect = $false
$page2ListView.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$page2ListView.Visible = $false

# Add columns for Page 2
$page2ListView.Columns.Add("Section", 300) | Out-Null
$page2ListView.Columns.Add("exe", 300) | Out-Null
$page2ListView.Columns.Add("exe64", 300) | Out-Null

$form.Controls.Add($page2ListView)

# Global variable to track current page
$global:currentPage = 1

# Function to populate Page 2 table
# Function to populate Page 2 table
# Function to populate Page 2 table
function Populate-Page2Table {
    $page2ListView.Items.Clear()
    
    if (-not $global:nlpData -or $global:nlpData.Count -eq 0) {
        return
    }
    
    # Get all filenames from Page 1 (lowercase for comparison)
    $page1Files = @()
    if ($global:allFiles -and $global:allFiles.Count -gt 0) {
        $page1Files = $global:allFiles | ForEach-Object { $_.Name.ToLower() }
    }
    
    $itemsToAdd = @()
    
    foreach ($entry in $global:nlpData.GetEnumerator() | Where-Object Key -like 'Software*') {
        $sectionName = $entry.Key
        $exe = $entry.Value.exe
        $exe64 = $entry.Value.exe64
        
        if ($exe -or $exe64) {
            # Create the main item
            $item = New-Object System.Windows.Forms.ListViewItem
            $item.Text = $sectionName
            
            # Determine what files are expected and what are found
            $exeExpected = ![string]::IsNullOrEmpty($exe)
            $exe64Expected = ![string]::IsNullOrEmpty($exe64)
            $exeFound = $exeExpected -and ($page1Files -contains $exe.ToLower())
            $exe64Found = $exe64Expected -and ($page1Files -contains $exe64.ToLower())
            
            # Add exe column with (MISSING) prefix if not found
            $exeValue = if ($exe) { 
                if (!$exeFound) { "(MISSING) $exe" } else { $exe }
            } else { "" }
            $item.SubItems.Add($exeValue) | Out-Null
            
            # Add exe64 column with (MISSING) prefix if not found
            $exe64Value = if ($exe64) { 
                if (!$exe64Found) { "(MISSING) $exe64" } else { $exe64 }
            } else { "" }
            $item.SubItems.Add($exe64Value) | Out-Null
            
            # Color logic:
            # Red: Both expected but both missing, OR only exe expected but missing, OR only exe64 expected but missing
            # Blue: Both expected but only one found
            if ($exeExpected -and $exe64Expected) {
                # Both exe and exe64 are expected
                if (!$exeFound -and !$exe64Found) {
                    # Both missing = Red
                    $item.ForeColor = [System.Drawing.Color]::Red
                } elseif ($exeFound -xor $exe64Found) {
                    # Only one found = Blue
                    $item.ForeColor = [System.Drawing.Color]::Blue
                }
                # Both found = default black (no color change)
            } elseif ($exeExpected -and !$exeFound) {
                # Only exe expected but missing = Red
                $item.ForeColor = [System.Drawing.Color]::Red
            } elseif ($exe64Expected -and !$exe64Found) {
                # Only exe64 expected but missing = Red
                $item.ForeColor = [System.Drawing.Color]::Red
            }
            
            $itemsToAdd += $item
        }
    }
    
    # Sort items by section name using natural numeric sorting
    $itemsToAdd = $itemsToAdd | Sort-Object {
        if ($_.Text -match '^Software(\d+)$') {
            [int]$matches[1]
        } else {
            999999  # Put non-numeric sections at the end
        }
    }
    
    # Add sorted items to ListView
    foreach ($item in $itemsToAdd) {
        $page2ListView.Items.Add($item) | Out-Null
    }
}

# Function to swap pages
function Swap-Pages {
    if ($global:currentPage -eq 1) {
        # Populate Page 2 table before showing it
        Populate-Page2Table
        
        # Hide Page 1 controls
        $listView.Visible = $false
        $runButton.Visible = $false
        $propertiesButton.Visible = $false
        $exportButton.Visible = $false
        $syncDatesButton.Visible = $false
        $fileCountLabel.Visible = $false
        $cmdLineLabel.Visible = $false
        $cmdLineTextBox.Visible = $false
        
        # Show Page 2 controls
        $page2ListView.Visible = $true
        $legendLabel1.Visible = $true
        $legendLabel2.Visible = $true
		
        # Update button text and page tracker
        $pageSwapButton.Text = "Page 1"
        $global:currentPage = 2
    } else {
        # Hide Page 2 controls
        $page2ListView.Visible = $false
        $legendLabel1.Visible = $false
        $legendLabel2.Visible = $false
        
        # Show Page 1 controls
        $listView.Visible = $true
        $runButton.Visible = $true
        $propertiesButton.Visible = $true
        $exportButton.Visible = $true
        $syncDatesButton.Visible = $true
        $fileCountLabel.Visible = $true
        $cmdLineLabel.Visible = $true
        $cmdLineTextBox.Visible = $true
        
        # Update button text and page tracker
        $pageSwapButton.Text = "Page 2"
        $global:currentPage = 1
    }
}

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
# Global variable to store NLP data for Page 2
$global:nlpData = @{}

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
            
            $duration = ""
			try {
				$shell = New-Object -ComObject Shell.Application
				$folderCom = $shell.Namespace($file.DirectoryName)
				$item     = $folderCom.ParseName($file.Name)
				# 27 is typically the "Duration" column index – may vary per system
				$duration = $folderCom.GetDetailsOf($item, 27)
			} catch {
				$duration = ""
			}

			$fileInfo = [PSCustomObject]@{
				Name           = $file.Name
				Extension      = $file.Extension
				Type           = if ($file.Extension) { "$($file.Extension.TrimStart('.').ToUpper()) File" } else { "File" }
                                Size           = $file.Length
                                SizeFormatted  = Format-FileSize -Size $file.Length
                                Description    = $description
                                Section        = $global:exeSectionMap[$file.Name.ToLower()]
                                FullPath       = $file.FullName
                                CreationTime   = $file.CreationTime.ToString('yyyy-MM-dd')
                                LastWriteTime  = $file.LastWriteTime.ToString('yyyy-MM-dd')
				LastAccessTime = $file.LastAccessTime.ToString('yyyy-MM-dd')
				Directory      = $file.DirectoryName
				Length         = $duration
			}
            
            $global:allFiles += $fileInfo
        }
        
        # Add items to ListView
        $statusLabel.Text = "Adding items to display..."
        $form.Update()
        
        foreach ($fileInfo in $global:allFiles) {
                        $item = New-Object System.Windows.Forms.ListViewItem($fileInfo.Name)
        # Highlight files not listed in JSON’s exe/exe64 keys
            if (-not ($global:exeList -contains $fileInfo.Name.ToLower())) {
                $item.ForeColor = 'Red'
                $item.SubItems.Add("")                  | Out-Null
            }
            else {
                $item.SubItems.Add($fileInfo.Section)    | Out-Null
            }
                        $item.SubItems.Add($fileInfo.Extension)      | Out-Null
                        $item.SubItems.Add($fileInfo.Type)           | Out-Null
                        $item.SubItems.Add($fileInfo.SizeFormatted)  | Out-Null
                        $item.SubItems.Add($fileInfo.Description)    | Out-Null
                        # New columns:
                        $item.SubItems.Add($fileInfo.CreationTime)   | Out-Null
                        $item.SubItems.Add($fileInfo.LastWriteTime)  | Out-Null
                        $item.SubItems.Add($fileInfo.LastAccessTime) | Out-Null
                        $item.SubItems.Add($fileInfo.Directory)      | Out-Null
                        $item.SubItems.Add($fileInfo.Length)         | Out-Null

                        $item.Tag = $fileInfo.FullPath
                        $listView.Items.Add($item)                  | Out-Null
                }
        $exportButton.Enabled = $true
        $progressBar.Visible = $false
        $fileCountLabel.Text = "Files: $($global:allFiles.Count)"
        $statusLabel.Text = "Loaded $($global:allFiles.Count) files successfully"
    }
    catch {
        $progressBar.Visible = $false
        $statusLabel.Text = "Error loading files: $($_.Exception.Message)"
    }
}
# Handle click to save CSV
$exportButton.Add_Click({
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter   = "CSV files (*.csv)|*.csv"
    $saveDialog.FileName = "FileProperties.csv"
    if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:allFiles | Export-Csv -Path $saveDialog.FileName -NoTypeInformation
        [System.Windows.Forms.MessageBox]::Show(
            "Exported to $($saveDialog.FileName)",
            "Export CSV",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
})
# Event handlers
# —— Replace existing Open JSON button handler (~line 407) with this:
$browseButton.Add_Click({
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $ofd = New-Object System.Windows.Forms.OpenFileDialog
        $ofd.Filter = "NLP Files (*.nlp)|*.nlp"
        $ofd.Title  = "Select NLP file to compare"
        if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

        # 1) Parse .nlp (INI format) into a hashtable
        $nlpPath = $ofd.FileName
        $lines   = Get-Content $nlpPath
        $ini     = @{};  $section = ""
        foreach ($l in $lines) {
            $t = $l.Trim()
            if ($t -match '^\[(.+)\]$') {
                $section = $matches[1]
                $ini[$section] = @{}
            }
            elseif ($t -match '^(.*?)=(.*)$' -and $section) {
                $ini[$section][$matches[1].Trim()] = $matches[2].Trim()
            }
        }

        # 2) Build lowercase exe/exe64 list and map each file to its section
        $global:exeList = @()
        $global:exeSectionMap = @{}

        foreach ($entry in $ini.GetEnumerator() | Where-Object Key -like 'Software*') {
            $sectionName = $entry.Key
            foreach ($exeName in @($entry.Value.exe, $entry.Value.exe64)) {
                if ($exeName) {
                    $lower = $exeName.ToLower()
                    $global:exeList += $lower
                    $global:exeSectionMap[$lower] = $sectionName
                }
            }
        }
         # Store the INI data globally for Page 2
        $global:nlpData = $ini
        $global:exeList = $global:exeList | Sort-Object -Unique

        # 3) Point at the .nlp’s folder and reload non-recursively
        $global:currentFolder    = Split-Path $nlpPath
        $folderTextBox.Text      = $currentFolder
        Load-Files -FolderPath $currentFolder `
                   -Filter $filterTextBox.Text `
                   -HideNoDesc:$hideNoDescCheckBox.Checked `
                   -Recursive:$false
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Error selecting NLP:`n$($_.Exception.Message)",
            "Error",[System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
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
# Handle Sync Mod Date click
$syncDatesButton.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Are you sure you want to update the modified date of all listed files to match their creation date?",
        "Confirm Sync Dates",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        foreach ($fileInfo in $global:allFiles) {
            try {
                $file = Get-Item $fileInfo.FullPath
                $file.LastWriteTime = $file.CreationTime
            } catch {
                # ignore individual errors
            }
        }
        [System.Windows.Forms.MessageBox]::Show(
            "Modification dates have been updated.",
            "Sync Complete",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        # Refresh display
        $filter = if ($filterTextBox.Text -eq "*.* (All files)") { "*.*" } else { $filterTextBox.Text }
        Load-Files -FolderPath $global:currentFolder `
                   -Filter $filter `
                   -HideNoDescription $hideNoDescCheckBox.Checked `
                   -Recursive $recursiveCheckBox.Checked
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
        1 { $items = $items | Sort-Object { $_.SubItems[1].Text } }  # Section
        2 { $items = $items | Sort-Object { $_.SubItems[2].Text } }  # Extension
        3 { $items = $items | Sort-Object { $_.SubItems[3].Text } }  # Type
        4 {
            # Sort by actual file size, not formatted string
            $items = $items | Sort-Object {
                $fileInfo = $global:allFiles | Where-Object { $_.FullPath -eq $_.Tag }
                if ($fileInfo) { $fileInfo.Size } else { 0 }
            }
        }
        5 { $items = $items | Sort-Object { $_.SubItems[5].Text } }  # File Description
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

# Page swap button event handler
$pageSwapButton.Add_Click({
    Swap-Pages
})

# Show form
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
