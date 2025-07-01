Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Inline XAML for the GUI (with xmlns:x declared)
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="File Merger" Height="500" Width="800">
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <Button x:Name="BrowseButton" Content="Browse Folder..." Grid.Row="0" Grid.Column="0" Margin="0,0,5,5" Width="120"/>
    <Button x:Name="RefreshButton" Content="Refresh"      Grid.Row="0" Grid.Column="2" Margin="5,0,0,5" Width="75"/>

    <ListBox x:Name="LeftList"  Grid.Row="1" Grid.Column="0" SelectionMode="Single" DisplayMemberPath="Name" Margin="0,0,5,0"/>
    <StackPanel Grid.Row="1" Grid.Column="1" Orientation="Vertical" HorizontalAlignment="Center" VerticalAlignment="Center">
      <Button x:Name="AddButton"    Content="&gt;"  Width="50" Margin="0,5"/>
      <Button x:Name="RemoveButton" Content="&lt;"  Width="50" Margin="0,5"/>
      <Button x:Name="UpButton"     Content="Up"    Width="50" Margin="0,5"/>
      <Button x:Name="DownButton"   Content="Down"  Width="50" Margin="0,5"/>
    </StackPanel>
    <ListBox x:Name="RightList" Grid.Row="1" Grid.Column="2" SelectionMode="Single" DisplayMemberPath="Name" Margin="5,0,0,0"/>

    <TextBlock x:Name="StatusText" Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="2" VerticalAlignment="Center" Margin="0,5,0,5"/>
    <Button x:Name="SaveButton"    Content="Save As..." Grid.Row="2" Grid.Column="2" HorizontalAlignment="Right" Margin="0,5,0,0" Width="100"/>
  </Grid>
</Window>
"@

# Load the XAML
$reader = New-Object System.Xml.XmlNodeReader -ArgumentList $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# Grab controls
$BrowseButton   = $window.FindName("BrowseButton")
$RefreshButton  = $window.FindName("RefreshButton")
$LeftList       = $window.FindName("LeftList")
$RightList      = $window.FindName("RightList")
$AddButton      = $window.FindName("AddButton")
$RemoveButton   = $window.FindName("RemoveButton")
$UpButton       = $window.FindName("UpButton")
$DownButton     = $window.FindName("DownButton")
$SaveButton     = $window.FindName("SaveButton")
$StatusText     = $window.FindName("StatusText")

# Data stores
$script:FolderPath     = ""
$script:AvailableFiles = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
$script:SelectedFiles  = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()

$LeftList.ItemsSource  = $script:AvailableFiles
$RightList.ItemsSource = $script:SelectedFiles

# Function to escape HTML
function Escape-Html {
  param([string]$s)
  return $s.Replace("&","&amp;").Replace("<","&lt;").Replace(">","&gt;").Replace('"',"&quot;")
}

# Refresh the left list from the folder
function Refresh-FileList {
  if (-not [string]::IsNullOrEmpty($script:FolderPath)) {
    $files = Get-ChildItem -Path $script:FolderPath -File | ForEach-Object {
      [PSCustomObject]@{ Name = $_.Name; FullName = $_.FullName }
    }
    $script:AvailableFiles.Clear()
    foreach ($f in $files) { $script:AvailableFiles.Add($f) }
    $StatusText.Text = "Found $($files.Count) files."
  }
}

# Browse folder
$BrowseButton.Add_Click({
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  if ($dlg.ShowDialog() -eq 'OK') {
    $script:FolderPath = $dlg.SelectedPath
    $StatusText.Text  = "Selected folder: $script:FolderPath"
    Refresh-FileList
  }
})

# Refresh button
$RefreshButton.Add_Click({ Refresh-FileList })

# Add file to right list (removes from left + auto-select next)
$AddButton.Add_Click({
  $item = $LeftList.SelectedItem
  if ($item) {
    $idx = $LeftList.SelectedIndex
    # remove from left
    $script:AvailableFiles.RemoveAt($idx)
    # add to right
    $script:SelectedFiles.Add($item)

    # select next on left
    if ($script:AvailableFiles.Count -gt 0) {
      if ($idx -lt $script:AvailableFiles.Count) {
        $LeftList.SelectedIndex = $idx
      } else {
        $LeftList.SelectedIndex = $script:AvailableFiles.Count - 1
      }
    }

    $StatusText.Text = "Added $($item.Name)"
  } else {
    $StatusText.Text = "Nothing selected."
  }
})

# Remove file from right list (re-adds to left)
$RemoveButton.Add_Click({
  $item = $RightList.SelectedItem
  if ($item) {
    $script:SelectedFiles.Remove($item)
    $script:AvailableFiles.Add($item)
    $StatusText.Text = "Removed $($item.Name)"
  }
})

# Move up in right list
$UpButton.Add_Click({
  $item = $RightList.SelectedItem
  if ($item) {
    $idx = $script:SelectedFiles.IndexOf($item)
    if ($idx -gt 0) {
      $script:SelectedFiles.RemoveAt($idx)
      $script:SelectedFiles.Insert($idx - 1, $item)
      $RightList.SelectedItem = $item
    }
  }
})

# Move down in right list
$DownButton.Add_Click({
  $item = $RightList.SelectedItem
  if ($item) {
    $idx = $script:SelectedFiles.IndexOf($item)
    if ($idx -lt $script:SelectedFiles.Count - 1) {
      $script:SelectedFiles.RemoveAt($idx)
      $script:SelectedFiles.Insert($idx + 1, $item)
      $RightList.SelectedItem = $item
    }
  }
})

# Save combined files as HTML
$SaveButton.Add_Click({
  if ($script:SelectedFiles.Count -eq 0) {
    [System.Windows.MessageBox]::Show("No files selected.","Warning")
    return
  }
  $dlg = New-Object Microsoft.Win32.SaveFileDialog
  $dlg.FileName    = "CombinedFiles.html"
  $dlg.DefaultExt  = ".html"
  $dlg.Filter      = "HTML files (*.html)|*.html|All files (*.*)|*.*"
  if ($dlg.ShowDialog() -eq $true) {
    $outPath = $dlg.FileName
    $sb = New-Object System.Text.StringBuilder
    $sb.AppendLine('<!DOCTYPE html>')
    $sb.AppendLine('<html><head><meta charset="utf-8"><title>Combined Files</title>')
    $sb.AppendLine('<style>')
    $sb.AppendLine('  body { font-family: Consolas, monospace; }')
    $sb.AppendLine('  .line-number { display: inline-block; width: 4em; text-align: right; color: gray; margin-right: 1em; }')
    $sb.AppendLine('  .line-content { white-space: pre; }')
    $sb.AppendLine('</style></head><body>')

    foreach ($f in $script:SelectedFiles) {
      $sb.AppendLine("<h2>$($f.Name)</h2>")
      $sb.AppendLine("<pre>")
      $lines = Get-Content -Path $f.FullName
      for ($i = 0; $i -lt $lines.Length; $i++) {
        $num  = $i + 1
        $text = Escape-Html $lines[$i]
        $sb.AppendLine("  <span class='line-number'>$num</span><span class='line-content'>$text</span>")
      }
      $sb.AppendLine("</pre>")
    }

    $sb.AppendLine('</body></html>')
    $sb.ToString() | Set-Content -LiteralPath $outPath -Encoding UTF8
    [System.Windows.MessageBox]::Show("Saved HTML to:`n$outPath","Success")
  }
})

# Enforce single selection by clearing the other when one is chosen
$LeftList.Add_SelectionChanged({ if ($LeftList.SelectedItem) { $RightList.SelectedIndex = -1 } })
$RightList.Add_SelectionChanged({ if ($RightList.SelectedItem) { $LeftList.SelectedIndex = -1 } })

# Show the window
$window.ShowDialog() | Out-Null
