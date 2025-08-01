#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete cleanup script for Kamiwaza WSL instances and related data
    
.DESCRIPTION
    This script completely removes Kamiwaza WSL instances, their data directories,
    configuration files, and logs. It's designed to be run during MSI uninstallation
    or manually for troubleshooting.
    
.PARAMETER Force
    Skip confirmation prompts and force cleanup
    
.PARAMETER Verbose
    Enable verbose output for debugging
    
.EXAMPLE
    .\cleanup_wsl_kamiwaza.ps1
    
.EXAMPLE
    .\cleanup_wsl_kamiwaza.ps1 -Force -Verbose
#>

param(
    [switch]$Force,
    [switch]$Verbose
)

# Enable verbose output if requested
if ($Verbose) {
    $VerbosePreference = "Continue"
}

Write-Host "=== KAMIWAZA WSL CLEANUP SCRIPT ===" -ForegroundColor Cyan
Write-Host "This script will completely remove Kamiwaza WSL instances and related data" -ForegroundColor Yellow

if (-not $Force) {
    $confirmation = Read-Host "Are you sure you want to proceed? (y/N)"
    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
        Write-Host "Cleanup cancelled by user" -ForegroundColor Red
        exit 0
    }
}

try {
    Write-Host "Starting WSL cleanup for Kamiwaza uninstallation..." -ForegroundColor Green
    
    # List all WSL instances to find kamiwaza-related ones
    Write-Verbose "Listing WSL instances..."
    $wslList = wsl --list --quiet 2>$null
    $kamiwazaInstances = @()
    
    # Check for various kamiwaza instance names
    $possibleNames = @("kamiwaza", "Ubuntu-24.04")
    
    # Also check for version-specific names by reading config if available
    $configPath = Join-Path $env:LOCALAPPDATA "Kamiwaza\config.yaml"
    if (Test-Path $configPath) {
        try {
            $configContent = Get-Content $configPath -Raw
            if ($configContent -match "kamiwaza_version:\s*([^\r\n]+)") {
                $version = $matches[1].Trim()
                $possibleNames += "kamiwaza-$version"
                Write-Verbose "Found version from config: $version"
            }
        } catch {
            Write-Verbose "Could not read config file: $($_.Exception.Message)"
        }
    }
    
    Write-Host "Checking for WSL instances: $($possibleNames -join ', ')" -ForegroundColor Yellow
    
    foreach ($name in $possibleNames) {
        if ($wslList -match $name) {
            $kamiwazaInstances += $name
            Write-Host "Found WSL instance: $name" -ForegroundColor Green
        }
    }
    
    if ($kamiwazaInstances.Count -eq 0) {
        Write-Host "No Kamiwaza WSL instances found" -ForegroundColor Yellow
    } else {
        Write-Host "Found $($kamiwazaInstances.Count) WSL instance(s) to clean up" -ForegroundColor Yellow
        
        # Stop and unregister each kamiwaza instance
        foreach ($instance in $kamiwazaInstances) {
            Write-Host "Processing WSL instance: $instance" -ForegroundColor Cyan
            
            try {
                # Stop the instance first
                Write-Verbose "Stopping WSL instance: $instance"
                wsl --terminate $instance 2>$null
                Start-Sleep -Seconds 2
                
                # Try to remove kamiwaza package if instance is still accessible
                Write-Verbose "Attempting to remove kamiwaza package from $instance"
                $removeResult = wsl -d $instance sudo apt remove --purge -y kamiwaza 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Successfully removed kamiwaza package from $instance" -ForegroundColor Green
                } else {
                    Write-Verbose "Could not remove kamiwaza package from $instance (may not be installed or instance not accessible)"
                }
                Start-Sleep -Seconds 1
                
                # Unregister the instance completely
                Write-Verbose "Unregistering WSL instance: $instance"
                $unregisterResult = wsl --unregister $instance 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Successfully unregistered: $instance" -ForegroundColor Green
                } else {
                    Write-Host "Warning: Could not unregister $instance - $unregisterResult" -ForegroundColor Yellow
                }
                
            } catch {
                Write-Host "Warning: Could not fully clean up $instance - attempting force unregister" -ForegroundColor Yellow
                try {
                    $forceResult = wsl --unregister $instance 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "Force unregistered: $instance" -ForegroundColor Green
                    } else {
                        Write-Host "Error: Could not unregister $instance - $forceResult" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "Error: Could not unregister $instance - $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
    
    # Clean up WSL data directory for kamiwaza
    $wslDataPath = Join-Path $env:LOCALAPPDATA "WSL\kamiwaza"
    if (Test-Path $wslDataPath) {
        Write-Host "Removing WSL data directory: $wslDataPath" -ForegroundColor Yellow
        try {
            Remove-Item -Path $wslDataPath -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully removed WSL data directory" -ForegroundColor Green
        } catch {
            Write-Host "Warning: Could not remove WSL data directory: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Verbose "WSL data directory not found: $wslDataPath"
    }
    
    # Clean up .wslconfig if it was created by kamiwaza
    $wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
    if (Test-Path $wslConfigPath) {
        Write-Host "Checking .wslconfig for kamiwaza-specific settings..." -ForegroundColor Yellow
        try {
            $content = Get-Content $wslConfigPath -Raw
            if ($content -match "memory=.*GB" -and $content -match "localhostForwarding=true") {
                Write-Host "Detected kamiwaza-specific .wslconfig - removing" -ForegroundColor Yellow
                Remove-Item $wslConfigPath -Force
                Write-Host "Removed .wslconfig" -ForegroundColor Green
            } else {
                Write-Host "Keeping .wslconfig (appears to have other configurations)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Warning: Could not check .wslconfig: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Verbose ".wslconfig not found: $wslConfigPath"
    }
    
    # Clean up AppData logs
    $appDataLogs = Join-Path $env:LOCALAPPDATA "Kamiwaza\logs"
    if (Test-Path $appDataLogs) {
        Write-Host "Removing Kamiwaza logs directory: $appDataLogs" -ForegroundColor Yellow
        try {
            Remove-Item -Path $appDataLogs -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully removed logs directory" -ForegroundColor Green
        } catch {
            Write-Host "Warning: Could not remove logs directory: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Verbose "Logs directory not found: $appDataLogs"
    }
    
    # Clean up the entire Kamiwaza AppData directory if it's empty
    $kamiwazaAppData = Join-Path $env:LOCALAPPDATA "Kamiwaza"
    if (Test-Path $kamiwazaAppData) {
        $remainingItems = Get-ChildItem -Path $kamiwazaAppData -Recurse -Force -ErrorAction SilentlyContinue
        if ($remainingItems.Count -eq 0) {
            Write-Host "Removing empty Kamiwaza AppData directory: $kamiwazaAppData" -ForegroundColor Yellow
            try {
                Remove-Item -Path $kamiwazaAppData -Force -ErrorAction Stop
                Write-Host "Successfully removed empty Kamiwaza AppData directory" -ForegroundColor Green
            } catch {
                Write-Host "Warning: Could not remove Kamiwaza AppData directory: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Verbose "Kamiwaza AppData directory not empty, keeping: $($remainingItems.Count) items remain"
        }
    }
    
    Write-Host "WSL cleanup completed successfully!" -ForegroundColor Green
    
} catch { 
    Write-Host "Error during WSL cleanup: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Continuing with cleanup..." -ForegroundColor Yellow
}

Write-Host "=== CLEANUP COMPLETE ===" -ForegroundColor Cyan 