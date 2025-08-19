# Kamiwaza Autostart Registry Setup Script
# This script creates a RunOnce registry entry to launch Kamiwaza after system restart
# No admin rights required - uses HKCU (current user) registry

param(
    [string]$ScriptPath = "",
    [string]$TaskName = "KamiwazaGPUAutostart"
)

Write-Host "=== Kamiwaza Autostart Registry Setup ===" -ForegroundColor Green
Write-Host "Setting up RunOnce entry for Kamiwaza autostart..." -ForegroundColor Yellow

try {
    # Determine the script path if not provided
    if (-not $ScriptPath) {
        $ScriptPath = Join-Path $PSScriptRoot "kamiwaza_autostart.bat"
        if (-not (Test-Path $ScriptPath)) {
            # Fallback to LocalAppData folder
            $ScriptPath = Join-Path $env:LOCALAPPDATA "Kamiwaza\kamiwaza_autostart.bat"
        }
    }
    
    # Verify the script exists
    if (-not (Test-Path $ScriptPath)) {
        Write-Error "Autostart script not found at: $ScriptPath"
        Write-Host "Please ensure kamiwaza_autostart.bat exists in the Kamiwaza installation folder." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Using autostart script: $ScriptPath" -ForegroundColor Cyan
    
    # Create the RunOnce registry entry
    $runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    $runOnceValue = "`"$ScriptPath`""
    
    # Ensure the RunOnce key exists
    if (-not (Test-Path $runOnceKey)) {
        New-Item -Path $runOnceKey -Force | Out-Null
        Write-Host "Created RunOnce registry key" -ForegroundColor Yellow
    }
    
    # Set the registry value
    Set-ItemProperty -Path $runOnceKey -Name $TaskName -Value $runOnceValue -Type String -Force
    
    # Verify the entry was created
    $createdValue = Get-ItemProperty -Path $runOnceKey -Name $TaskName -ErrorAction SilentlyContinue
    if ($createdValue -and $createdValue.$TaskName -eq $runOnceValue) {
        Write-Host "[INFO] RunOnce registry entry created successfully!" -ForegroundColor Green
        Write-Host "Entry: $TaskName = $runOnceValue" -ForegroundColor Cyan
        Write-Host "Kamiwaza will start automatically after the next system restart." -ForegroundColor Green
    } else {
        Write-Error "Failed to verify registry entry creation"
        exit 1
    }
    
    # Create restart flag file for the autostart script
    $flagDir = Join-Path $env:LOCALAPPDATA "Kamiwaza"
    if (-not (Test-Path $flagDir)) {
        New-Item -ItemType Directory -Path $flagDir -Force | Out-Null
        Write-Host "Created Kamiwaza directory: $flagDir" -ForegroundColor Yellow
    }
    
    $flagFile = Join-Path $flagDir "restart_required.flag"
    Set-Content -Path $flagFile -Value "GPU setup completed - Kamiwaza should start automatically after restart"
    Write-Host "[INFO] Restart flag created: $flagFile" -ForegroundColor Green
    
    Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Restart your system when ready" -ForegroundColor White
    Write-Host "2. After restart, Kamiwaza will start automatically" -ForegroundColor White
    Write-Host "3. The autostart script will clean up the registry entry" -ForegroundColor White
    
} catch {
    Write-Error "Failed to create autostart registry entry: $($_.Exception.Message)"
    Write-Host "Error details: $($_.Exception.GetType().Name)" -ForegroundColor Red
    exit 1
} 