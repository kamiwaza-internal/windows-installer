# Kamiwaza Autostart Registry Setup Script
# This script creates a persistent Run registry entry to launch Kamiwaza at every user logon
# No admin rights required - uses HKCU (current user) registry
Write-Host "AUTOSTART REGISTRY"

param(
    [string]$ScriptPath = "",
    [string]$TaskName = "KamiwazaAutoStart"
)

$ErrorActionPreference = 'SilentlyContinue'

try {
    # Determine the script path if not provided
    if (-not $ScriptPath) {
        $ScriptPath = Join-Path $PSScriptRoot "kamiwaza_start.bat"
        if (-not (Test-Path $ScriptPath)) {
            # Fallback to LocalAppData folder
            $ScriptPath = Join-Path $env:LOCALAPPDATA "Kamiwaza\kamiwaza_start.bat"
        }
    }
    
    # Verify the script exists
    if (-not (Test-Path $ScriptPath)) {
        Write-Error "Autostart script not found at: $ScriptPath"
        exit 1
    }
    
    # Create the persistent Run registry entry (every logon)
    $runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $runValue = "`"$ScriptPath`""
    
    # Ensure the Run key exists
    if (-not (Test-Path $runKey)) { New-Item -Path $runKey -Force | Out-Null }
    
    # Set the registry value
    Set-ItemProperty -Path $runKey -Name $TaskName -Value $runValue -Type String -Force
    exit 0
} catch {
    Write-Error "Failed to create autostart registry entry: $($_.Exception.Message)"
    exit 1
}