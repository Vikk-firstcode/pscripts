<#
# ===========================================================
# DriverStore Cleanup with Audit, Backup, and Rollback
# ===========================================================
This script is for windows OS to to cleanup and get space on system drive.
Driver location -- "C:\Windows\System32\DriverStore"

#>


# Define backup path
$backupPath = "C:\Temp\DriverBackup"
if (!(Test-Path $backupPath)) {
    New-Item -ItemType Directory -Path $backupPath | Out-Null
}

# Start transcript for audit logging
$logFile = Join-Path $backupPath "Driver_AuditLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $logFile -Append

try {
    Write-Host "=== Step 1: Creating System Restore Point ==="
    Checkpoint-Computer -Description "DriverStoreCleanup" -RestorePointType "MODIFY_SETTINGS"
    Write-Host "System restore point created."

    Write-Host "=== Step 2: Exporting Drivers for Backup ==="
    $exportPath = Join-Path $backupPath "ExportedDrivers_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Export-WindowsDriver -Online -Destination $exportPath
    Write-Host "Drivers exported to $exportPath"

    Write-Host "=== Step 3: Auditing DriverStore ==="
    $drivers = Get-WindowsDriver -Online | Sort-Object ProviderName, ClassName, Version
    Write-Host "Total drivers found: $($drivers.Count)"

    # Export full driver list to CSV
    $csvFile = Join-Path $backupPath "DriverStore_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $drivers | Select-Object ProviderName, ClassName, Version, Date, Driver, BootCritical |
        Export-Csv -Path $csvFile -NoTypeInformation
    Write-Host "Driver report exported to $csvFile"

    # Group by driver class/provider to detect duplicates
    $grouped = $drivers | Group-Object ClassName

    foreach ($group in $grouped) {
        Write-Host "`nDriver Class: $($group.Name)"
        $group.Group | Format-Table ProviderName, Version, Date, Driver, BootCritical
    }

    Write-Host "=== Step 4: Cleanup Old Drivers (Non-Boot Critical) ==="
    foreach ($group in $grouped) {
        $latest = $group.Group | Sort-Object Version -Descending | Select-Object -First 1
        $old = $group.Group | Where-Object { $_.Driver -ne $latest.Driver -and $_.BootCritical -eq $false }

        foreach ($drv in $old) {
            Write-Host "Removing old driver: $($drv.Driver)"
            pnputil /delete-driver $drv.Driver /uninstall /force
        }
    }
}
finally {
    # Stop transcript
    Stop-Transcript
    Write-Host "Audit log saved to $logFile"
}
