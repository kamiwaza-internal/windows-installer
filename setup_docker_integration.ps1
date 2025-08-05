#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure Docker Desktop integration with Kamiwaza WSL instance
    
.DESCRIPTION
    This script implements both methods to enable Docker Desktop integration:
    1. Sets Kamiwaza as the default WSL distribution
    2. Adds Kamiwaza to Docker Desktop's integrated WSL distros list
    
    The script ensures Docker Desktop can communicate with the Kamiwaza WSL instance
    without requiring manual GUI configuration.
    
.PARAMETER DistroName
    Name of the WSL distribution to integrate (default: kamiwaza)
    
.PARAMETER Force
    Skip confirmation prompts and force configuration
    
.PARAMETER Verbose
    Enable verbose output for debugging
    
.PARAMETER SkipDefault
    Skip setting the distro as default WSL distribution
    
.EXAMPLE
    .\setup_docker_integration.ps1
    
.EXAMPLE
    .\setup_docker_integration.ps1 -Force -Verbose
    
.EXAMPLE
    .\setup_docker_integration.ps1 -DistroName "kamiwaza" -SkipDefault
#>

param(
    [string]$DistroName = "kamiwaza",
    [switch]$Force,
    [switch]$Verbose,
    [switch]$SkipDefault
)

# Enable verbose output if requested
if ($Verbose) {
    $VerbosePreference = "Continue"
}

Write-Host "=== DOCKER DESKTOP INTEGRATION SETUP ===" -ForegroundColor Cyan
Write-Host "Configuring Docker Desktop integration with WSL distribution: $DistroName" -ForegroundColor Yellow

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "WARNING: Not running as Administrator. Some operations may fail." -ForegroundColor Yellow
    if (-not $Force) {
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") {
            Write-Host "Setup cancelled. Run as Administrator for best results." -ForegroundColor Red
            exit 1
        }
    }
}

# Verify WSL distribution exists
Write-Host "Checking if WSL distribution '$DistroName' exists..." -ForegroundColor Yellow
try {
    $wslList = wsl --list --quiet 2>$null
    $distroExists = $wslList -contains $DistroName
    
    if (-not $distroExists) {
        Write-Host "ERROR: WSL distribution '$DistroName' not found!" -ForegroundColor Red
        Write-Host "Available distributions:" -ForegroundColor Yellow
        $wslList | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
        exit 1
    }
    
    Write-Host "[OK] WSL distribution '$DistroName' found" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Could not list WSL distributions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Method 1: Set as default WSL distribution
if (-not $SkipDefault) {
    Write-Host "`n--- METHOD 1: Setting '$DistroName' as default WSL distribution ---" -ForegroundColor Cyan
    
    try {
        # Get current default
        $currentDefault = wsl --list --verbose 2>$null | Where-Object { $_ -match '\*' } | ForEach-Object { 
            ($_ -split '\s+')[1] 
        }
        
        if ($currentDefault -eq $DistroName) {
            Write-Host "[OK] '$DistroName' is already the default WSL distribution" -ForegroundColor Green
        } else {
            Write-Host "Current default WSL distribution: $currentDefault" -ForegroundColor Yellow
            Write-Host "Setting '$DistroName' as default WSL distribution..." -ForegroundColor Yellow
            
            $result = wsl --set-default $DistroName 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Successfully set '$DistroName' as default WSL distribution" -ForegroundColor Green
            } else {
                Write-Host "ERROR: Failed to set default WSL distribution: $result" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "ERROR: Could not set default WSL distribution: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "Skipping default WSL distribution setup (SkipDefault flag enabled)" -ForegroundColor Yellow
}

# Method 2: Edit Docker Desktop settings file
Write-Host "`n--- METHOD 2: Configuring Docker Desktop settings ---" -ForegroundColor Cyan

# Check if Docker Desktop is installed
$dockerPaths = @(
    "C:\Program Files\Docker\Docker\Docker Desktop.exe",
    "C:\Program Files (x86)\Docker\Docker\Docker Desktop.exe"
)

$dockerPath = $null
foreach ($path in $dockerPaths) {
    if (Test-Path $path) {
        $dockerPath = $path
        break
    }
}

if (-not $dockerPath) {
    Write-Host "WARNING: Docker Desktop not found in standard locations" -ForegroundColor Yellow
    Write-Host "Skipping Docker Desktop configuration" -ForegroundColor Yellow
} else {
    Write-Host "[OK] Found Docker Desktop at: $dockerPath" -ForegroundColor Green
    
    try {
        # Stop Docker Desktop if running
        Write-Host "Stopping Docker Desktop..." -ForegroundColor Yellow
        $dockerProcesses = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
        if ($dockerProcesses) {
            try {
                taskkill /IM "Docker Desktop.exe" /F 2>$null
                Write-Host "[OK] Docker Desktop stopped" -ForegroundColor Green
            } catch {
                Write-Host "Warning: Could not stop Docker Desktop gracefully" -ForegroundColor Yellow
            }
        } else {
            Write-Host "[OK] Docker Desktop not running" -ForegroundColor Green
        }
        
        # Shutdown WSL to ensure clean state
        Write-Host "Shutting down WSL..." -ForegroundColor Yellow
        wsl --shutdown 2>$null
        Start-Sleep -Seconds 3
        Write-Host "[OK] WSL shutdown complete" -ForegroundColor Green
        
        # Locate settings file (try both possible locations)
        $settingsPath = Join-Path $env:APPDATA "Docker\settings-store.json"
        if (-not (Test-Path $settingsPath)) {
            $settingsPath = Join-Path $env:APPDATA "Docker\settings.json"
        }
        
        if (-not (Test-Path $settingsPath)) {
            Write-Host "WARNING: Docker Desktop settings file not found" -ForegroundColor Yellow
            Write-Host "Expected locations:" -ForegroundColor Yellow
            Write-Host "  - $env:APPDATA\Docker\settings-store.json" -ForegroundColor Gray
            Write-Host "  - $env:APPDATA\Docker\settings.json" -ForegroundColor Gray
        } else {
            Write-Host "[OK] Found Docker settings file: $settingsPath" -ForegroundColor Green
            
            # Backup original settings
            $backupPath = "$settingsPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $settingsPath $backupPath -Force
            Write-Host "[OK] Created backup: $backupPath" -ForegroundColor Green
            
            # Load and modify settings
            Write-Host "Modifying Docker Desktop settings..." -ForegroundColor Yellow
            $jsonContent = Get-Content $settingsPath -Raw -Encoding UTF8
            $settings = $jsonContent | ConvertFrom-Json
            
            # Ensure integratedWslDistros property exists
            if (-not $settings.PSObject.Properties['integratedWslDistros']) {
                $settings | Add-Member -MemberType NoteProperty -Name 'integratedWslDistros' -Value @()
                Write-Verbose "Added integratedWslDistros property"
            }
            
            # Add our distro if not already present
            if ($settings.integratedWslDistros -notcontains $DistroName) {
                $settings.integratedWslDistros += $DistroName
                Write-Host "[OK] Added '$DistroName' to integrated WSL distros" -ForegroundColor Green
            } else {
                Write-Host "[OK] '$DistroName' already in integrated WSL distros" -ForegroundColor Green
            }
            
            # Ensure default WSL integration is enabled
            if (-not $settings.PSObject.Properties['enableIntegrationWithDefaultWslDistro']) {
                $settings | Add-Member -MemberType NoteProperty -Name 'enableIntegrationWithDefaultWslDistro' -Value $true
                Write-Host "[OK] Enabled integration with default WSL distro" -ForegroundColor Green
            } else {
                $settings.enableIntegrationWithDefaultWslDistro = $true
                Write-Host "[OK] Ensured integration with default WSL distro is enabled" -ForegroundColor Green
            }
            
            # Save modified settings
            $modifiedJson = $settings | ConvertTo-Json -Depth 10 -Compress:$false
            Set-Content $settingsPath -Value $modifiedJson -Encoding UTF8 -Force
            Write-Host "[OK] Docker Desktop settings updated successfully" -ForegroundColor Green
            
            Write-Verbose "Current integrated distros: $($settings.integratedWslDistros -join ', ')"
        }
        
        # Restart Docker Desktop
        Write-Host "Starting Docker Desktop..." -ForegroundColor Yellow
        Start-Process $dockerPath -WindowStyle Hidden
        Write-Host "[OK] Docker Desktop started" -ForegroundColor Green
        
        # Wait a moment for Docker to initialize
        Write-Host "Waiting for Docker Desktop to initialize..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        
    } catch {
        Write-Host "ERROR: Failed to configure Docker Desktop: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== SETUP COMPLETE ===" -ForegroundColor Cyan
Write-Host "Docker Desktop integration with '$DistroName' has been configured!" -ForegroundColor Green

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Wait for Docker Desktop to fully start (may take 1-2 minutes)" -ForegroundColor Gray
Write-Host "2. Open Docker Desktop → Settings → Resources → WSL integration" -ForegroundColor Gray
Write-Host "3. Verify that '$DistroName' toggle is enabled (blue)" -ForegroundColor Gray
Write-Host "4. Test by running: wsl -d $DistroName -- docker version" -ForegroundColor Gray

Write-Host "`nIf integration doesn't work immediately:" -ForegroundColor Yellow
Write-Host "- Restart Docker Desktop completely" -ForegroundColor Gray
Write-Host "- Check that WSL 2 is enabled for Docker Desktop" -ForegroundColor Gray
Write-Host "- Ensure '$DistroName' is running WSL 2 (not WSL 1)" -ForegroundColor Gray

Write-Host "`n=== INTEGRATION SETUP COMPLETE ===" -ForegroundColor Cyan