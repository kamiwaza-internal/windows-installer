# Kamiwaza Autostart Registry Setup Script
# This script creates a persistent Run registry entry to launch Kamiwaza at every user logon
# No admin rights required - uses HKCU (current user) registry
# Also sets the StartupApproved entry to ensure the app appears as enabled in Task Manager

param(
    [string]$AppPath = "",
    [string]$TaskName = "Kamiwaza"
)

$ErrorActionPreference = 'SilentlyContinue'

try {
    # Determine the app path if not provided
    if (-not $AppPath) {
        $AppPath = Join-Path $env:LOCALAPPDATA "Kamiwaza\KamiwazaManager.exe"
    }
    
    # Verify the app exists
    if (-not (Test-Path $AppPath)) {
        Write-Error "KamiwazaManager.exe not found at: $AppPath"
        exit 1
    }
    
    # Create the persistent Run registry entry (every logon)
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $runValue = "`"$AppPath`""
    
    # Ensure the Run key exists
    if (-not (Test-Path $runKey)) { New-Item -Path $runKey -Force | Out-Null }
    
    # Set the registry value
    Set-ItemProperty -Path $runKey -Name $TaskName -Value $runValue -Type String -Force
    Write-Host "Created Run registry entry: $TaskName"
    
    # Set the StartupApproved entry to ensure it appears as enabled in Task Manager
    $startupApprovedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StartupApproved"
    $startupApprovedValue = [byte[]](0x02, 0x00, 0x00, 0x00)  # Binary value for "enabled"
    
    # Ensure the StartupApproved key exists
    if (-not (Test-Path $startupApprovedKey)) { New-Item -Path $startupApprovedKey -Force | Out-Null }
    
    # Set the StartupApproved registry value
    Set-ItemProperty -Path $startupApprovedKey -Name $TaskName -Value $startupApprovedValue -Type Binary -Force
    Write-Host "Set StartupApproved registry entry: $TaskName (enabled)"
    
    Write-Host "Kamiwaza autostart configured successfully!"
    Write-Host "The app will now start automatically at login and appear as enabled in Task Manager."
    exit 0
} catch {
    Write-Error "Failed to create autostart registry entry: $($_.Exception.Message)"
    exit 1
} 