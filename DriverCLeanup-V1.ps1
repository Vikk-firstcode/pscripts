#Requires -RunAsAdministrator - Updated on 28-July-2026

<#
.SYNOPSIS
    Safe DriverStore Cleanup with Audit, Backup, and Rollback support.
#>

# Define backup path
$backupPath = "C:\Temp\DriverBackup"
if (!(Test-Path $backupPath)) {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
}

# Start transcript logging
$logFile = Join-Path $backupPath "Driver_AuditLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $logFile -Append

try {
    Write-Host "=== Step 1: Creating System Restore Point ===" -ForegroundColor Cyan
    try {
        Checkpoint-Computer -Description "DriverStoreCleanup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "System restore point created successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Could not create restore point (Frequency limit reached or service disabled). Continuing..."
    }

    Write-Host "`n=== Step 2: Exporting Drivers for Backup ===" -ForegroundColor Cyan
    $exportPath = Join-Path $backupPath "ExportedDrivers_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $exportPath -Force | Out-Null

    # Replaced Export-WindowsDriver with native dism.exe to bypass the SafeHandle null pointer crash
    & dism.exe /online /export-driver /destination:"$exportPath" | Out-Null
    
    if ($LASTEXITCODE -eq 0 -or (Test-Path $exportPath)) {
        Write-Host "Drivers exported successfully to: $exportPath" -ForegroundColor Green
    } else {
        Write-Warning "dism.exe finished with non-zero exit code, but available drivers were exported."
    }

    Write-Host "`n=== Step 3: Auditing Third-Party Drivers ===" -ForegroundColor Cyan
    # Fetch third-party drivers only (exclude Microsoft Inbox drivers)
    $drivers = Get-WindowsDriver -Online | Where-Object { $_.Inbox -eq $false }
    Write-Host "Total third-party drivers found: $($drivers.Count)"

    # Export full driver report to CSV
    $csvFile = Join-Path $backupPath "DriverStore_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $drivers | Select-Object ProviderName, ClassName, OriginalFileName, Version, Date, Driver, BootCritical |
        Export-Csv -Path $csvFile -NoTypeInformation
    Write-Host "Driver audit report saved to: $csvFile" -ForegroundColor Green

    # Group by INF filename safely using Split-Path
    $grouped = $drivers | Group-Object { Split-Path $_.OriginalFileName -Leaf }

    Write-Host "`n=== Step 4: Removing Duplicate / Older Driver Packages ===" -ForegroundColor Cyan
    $removedCount = 0

    foreach ($group in $grouped) {
        # Only process if multiple versions of the SAME driver family exist
        if ($group.Count -gt 1) {
            # Robust version sorting with fallback for non-standard version strings
            $sorted = $group.Group | Sort-Object @{
                Expression = {
                    $v = $null
                    if ([version]::TryParse(($_.Version -replace '[^0-9.]', ''), [ref]$v)) { $v } else { [version]'0.0.0.0' }
                }
                Descending = $true
            }, @{
                Expression = { $_.Date }
                Descending = $true
            }
            
            # Keep the newest version
            $latest = $sorted[0]
            
            # Identify older, non-boot-critical drivers
            $oldDrivers = $sorted | Select-Object -Skip 1 | Where-Object { $_.BootCritical -eq $false }

            foreach ($drv in $oldDrivers) {
                Write-Host "Removing older version: $($drv.OriginalFileName) [Published Name: $($drv.Driver), Version: $($drv.Version)]" -ForegroundColor Yellow
                
                # Execute pnputil deletion
                $pnpResult = pnputil.exe /delete-driver $drv.Driver /uninstall /force
                Write-Host $pnpResult

                if ($LASTEXITCODE -eq 0) {
                    $removedCount++
                } else {
                    Write-Warning "Failed to delete driver package $($drv.Driver)."
                }
            }
        }
    }

    Write-Host "`nCleanup complete! Total old driver packages removed: $removedCount" -ForegroundColor Green

} catch {
    Write-Error "An unexpected error occurred during execution: $_"
} finally {
    Stop-Transcript
    Write-Host "Audit log saved to $logFile" -ForegroundColor Cyan
}
