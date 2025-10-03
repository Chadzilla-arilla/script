[CmdletBinding()]
param(
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

$scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent -Path $MyInvocation.MyCommand.Path }
if (-not $ConfigPath) {
    $ConfigPath = Join-Path -Path $scriptDirectory -ChildPath 'backup-config.json'
}

$LogPath = Join-Path -Path $scriptDirectory -ChildPath 'backup.log'

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = (Get-Date).ToString('s')
    $entry = '{0} [{1}] {2}' -f $timestamp, $Level, $Message
    try {
        Add-Content -Path $LogPath -Value $entry -Encoding UTF8 -ErrorAction Stop
    } catch {
        # Logging failures remain silent by design
    }
}

function Resolve-ConfiguredPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $scriptDirectory -ChildPath $PathValue))
}

function Test-SharingViolation {
    param(
        [Parameter(Mandatory = $true)]
        [System.Exception]$Exception
    )

    $current = $Exception
    while ($current) {
        if ($current -is [System.IO.IOException]) {
            $lowWord = $current.HResult -band 0xFFFF
            if ($lowWord -eq 0x20) {
                return $true
            }

            $message = $current.Message
            if ($message -and ($message -match 'used by another process' -or $message -match 'sharing violation')) {
                return $true
            }
        }
        $current = $current.InnerException
    }

    return $false
}

function Invoke-ExcelFallback {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $excel = $null
    $workbook = $null

    try {
        try {
            $excel = [Runtime.InteropServices.Marshal]::GetActiveObject('Excel.Application')
        } catch {
            throw "Excel automation is unavailable: $($_.Exception.Message)"
        }

        $count = 0
        try {
            $count = $excel.Workbooks.Count
        } catch {
            $count = 0
        }

        for ($index = 1; $index -le $count; $index++) {
            $candidate = $excel.Workbooks.Item($index)
            if ($candidate.FullName -and ($candidate.FullName -ieq $TargetPath)) {
                $workbook = $candidate
                break
            } else {
                [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($candidate)
            }
        }

        if (-not $workbook) {
            throw 'Target workbook is not open in Excel.'
        }

        if (Test-Path -LiteralPath $DestinationPath) {
            Remove-Item -LiteralPath $DestinationPath -Force -ErrorAction Stop
        }

        try {
            $workbook.SaveCopyAs($DestinationPath)
        } catch {
            throw "Excel SaveCopyAs failed: $($_.Exception.Message)"
        }
    }
    finally {
        if ($workbook) {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)
        }
        if ($excel) {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
        }
    }
}

try {
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        Write-Log -Message ('Configuration file not found at {0}' -f $ConfigPath) -Level 'ERROR'
        exit 1
    }

    try {
        $configContent = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop
        $config = $configContent | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Log -Message ('Failed to read or parse configuration: {0}' -f $_.Exception.Message) -Level 'ERROR'
        exit 1
    }

    $targetPath = Resolve-ConfiguredPath -PathValue $config.TargetPath
    if (-not $targetPath) {
        Write-Log -Message 'TargetPath is missing or empty in the configuration.' -Level 'ERROR'
        exit 1
    }

    if (-not (Test-Path -LiteralPath $targetPath)) {
        Write-Log -Message ('Target file not found: {0}' -f $targetPath) -Level 'ERROR'
        exit 1
    }

    $backupDirectory = Resolve-ConfiguredPath -PathValue $config.BackupDirectory
    if (-not $backupDirectory) {
        Write-Log -Message 'BackupDirectory is missing or empty in the configuration.' -Level 'ERROR'
        exit 1
    }

    if (-not (Test-Path -LiteralPath $backupDirectory)) {
        try {
            New-Item -ItemType Directory -Path $backupDirectory -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Log -Message ('Unable to create backup directory {0}: {1}' -f $backupDirectory, $_.Exception.Message) -Level 'ERROR'
            exit 1
        }
    }

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($targetPath)
    $extension = [System.IO.Path]::GetExtension($targetPath)
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupFileName = '{0}-{1}{2}' -f $fileName, $timestamp, $extension
    $finalBackupPath = Join-Path -Path $backupDirectory -ChildPath $backupFileName
    $temporaryBackupPath = '{0}.partial' -f $finalBackupPath

    $copySucceeded = $false
    $copyError = $null

    try {
        Copy-Item -LiteralPath $targetPath -Destination $temporaryBackupPath -Force -ErrorAction Stop
        Move-Item -LiteralPath $temporaryBackupPath -Destination $finalBackupPath -Force -ErrorAction Stop
        Write-Log -Message ('Backup created: {0}' -f $finalBackupPath)
        $copySucceeded = $true
    } catch {
        if (Test-Path -LiteralPath $temporaryBackupPath) {
            Remove-Item -LiteralPath $temporaryBackupPath -Force -ErrorAction SilentlyContinue
        }
        $copyError = $_
    }

    if (-not $copySucceeded) {
        if ($copyError -and (Test-SharingViolation -Exception $copyError.Exception)) {
            try {
                Invoke-ExcelFallback -TargetPath $targetPath -DestinationPath $finalBackupPath
                Write-Log -Message ('Backup created via Excel fallback: {0}' -f $finalBackupPath)
                $copySucceeded = $true
            } catch {
                Write-Log -Message ('Backup failed after Excel fallback: {0}' -f $_.Exception.Message) -Level 'ERROR'
                exit 1
            }
        } elseif ($copyError) {
            Write-Log -Message ('Backup failed: {0}' -f $copyError.Exception.Message) -Level 'ERROR'
            exit 1
        } else {
            Write-Log -Message 'Backup failed for an unknown reason.' -Level 'ERROR'
            exit 1
        }
    }

    $retentionDays = $null
    if ($config.PSObject.Properties.Name -contains 'RetentionDays' -and $null -ne $config.RetentionDays -and ('{0}' -f $config.RetentionDays)) {
        $parsedRetention = 0
        if ([int]::TryParse($config.RetentionDays.ToString(), [ref]$parsedRetention) -and $parsedRetention -gt 0) {
            $retentionDays = $parsedRetention
        } else {
            Write-Log -Message ('RetentionDays value is invalid: {0}' -f $config.RetentionDays) -Level 'WARN'
        }
    }

    if ($retentionDays) {
        $cutoff = (Get-Date).AddDays(-$retentionDays)
        try {
            Get-ChildItem -Path $backupDirectory -File -Filter ('{0}-*{1}' -f $fileName, $extension) -ErrorAction Stop |
                Where-Object { $_.LastWriteTime -lt $cutoff } |
                ForEach-Object {
                    try {
                        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                        Write-Log -Message ('Removed old backup: {0}' -f $_.FullName)
                    } catch {
                        Write-Log -Message ('Failed to remove old backup {0}: {1}' -f $_.FullName, $_.Exception.Message) -Level 'WARN'
                    }
                }
        } catch {
            Write-Log -Message ('Retention cleanup failed: {0}' -f $_.Exception.Message) -Level 'WARN'
        }
    }
}
catch {
    Write-Log -Message ('Unhandled error: {0}' -f $_.Exception.Message) -Level 'ERROR'
    exit 1
}
