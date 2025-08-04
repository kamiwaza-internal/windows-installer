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
    
.PARAMETER AutoRemoveWSL
    Automatically remove WSL features if no distributions remain (used by MSI uninstaller)
    
.EXAMPLE
    .\cleanup_wsl_kamiwaza.ps1
    
.EXAMPLE
    .\cleanup_wsl_kamiwaza.ps1 -Force -Verbose
    
.EXAMPLE
    .\cleanup_wsl_kamiwaza.ps1 -Force -AutoRemoveWSL
#>

param(
    [switch]$Force,
    [switch]$Verbose,
    [switch]$AutoRemoveWSL
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
    
    # First, shutdown all WSL instances to ensure clean state
    Write-Host "Shutting down all WSL instances..." -ForegroundColor Yellow
    wsl --shutdown 2>$null
    Start-Sleep -Seconds 3
    Write-Host "✓ WSL shutdown complete" -ForegroundColor Green
    
    # List all WSL instances to find kamiwaza-related ones
    Write-Verbose "Listing WSL instances..."
    $wslListOutput = wsl --list --verbose 2>$null
    $kamiwazaInstances = @()
    
    # Check for various kamiwaza instance names
    $possibleNames = @("kamiwaza", "Ubuntu-24.04")
    
    # Also check for version-specific names by reading config if available
    $configPath = Join-Path $env:LOCALAPPDATA "Kamiwaza\config.yaml"
    if (Test-Path $configPath) {
        try {
            $configContent = Get-Content $configPath -Raw
            if ($configContent -match "kamiwaza_version:\s*(.+)") {
                $version = $matches[1].Trim()
                $possibleNames += "kamiwaza-$version"
                Write-Verbose "Found version from config: $version"
            }
        } catch {
            Write-Verbose "Could not read config file: $($_.Exception.Message)"
        }
    }
    
    Write-Host "Checking for WSL instances: $($possibleNames -join ', ')" -ForegroundColor Yellow
    Write-Host "Debug: WSL list output:" -ForegroundColor Cyan
    Write-Host "$wslListOutput" -ForegroundColor Gray
    
    # Parse WSL list output more carefully
    if ($wslListOutput) {
        $lines = $wslListOutput -split "`n" 
        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()
            if ($trimmedLine -and $trimmedLine -notmatch "NAME" -and $trimmedLine -notmatch "----") {
                # Extract distribution name (first column, handling * for default)
                $parts = $trimmedLine -split "\s+"
                if ($parts.Length -gt 0) {
                    $distroName = $parts[0] -replace "\*", ""  # Remove default marker
                    $distroName = $distroName.Trim()
                    
                    foreach ($name in $possibleNames) {
                        if ($distroName -eq $name) {
                            $kamiwazaInstances += $distroName
                            Write-Host "Found WSL instance: $distroName" -ForegroundColor Green
                            break
                        }
                    }
                }
            }
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
    
    # Clean up WSL data directories with retry logic
    foreach ($instance in $kamiwazaInstances) {
        $wslDataPath = Join-Path $env:LOCALAPPDATA "WSL\$instance"
        if (Test-Path $wslDataPath) {
            Write-Host "Removing WSL data directory: $wslDataPath" -ForegroundColor Yellow
            
            $maxRetries = 5
            $success = $false
            
            for ($retry = 1; $retry -le $maxRetries; $retry++) {
                try {
                    if ($retry -gt 1) {
                        Write-Host "Retry $retry/$maxRetries - Ensuring WSL is shutdown..." -ForegroundColor Yellow
                        wsl --shutdown 2>$null
                        Start-Sleep -Seconds 2
                        
                        # Kill any remaining WSL processes
                        Get-Process -Name "wsl*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds 1
                    }
                    
                    Remove-Item -Path $wslDataPath -Recurse -Force -ErrorAction Stop
                    Write-Host "✓ Successfully removed WSL data directory" -ForegroundColor Green
                    $success = $true
                    break
                } catch {
                    if ($retry -lt $maxRetries) {
                        Write-Host "Attempt $retry failed, retrying... ($($_.Exception.Message))" -ForegroundColor Yellow
                        Start-Sleep -Seconds 2
                    } else {
                        Write-Host "⚠ Warning: Could not remove WSL data directory after $maxRetries attempts: $($_.Exception.Message)" -ForegroundColor Yellow
                        Write-Host "You may need to restart your computer and run the cleanup script again" -ForegroundColor Yellow
                    }
                }
            }
        }
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
    }
    
    # Clean up AppData directories
    $kamiwazaAppData = Join-Path $env:LOCALAPPDATA "Kamiwaza"
    if (Test-Path $kamiwazaAppData) {
        Write-Host "Removing Kamiwaza AppData directory: $kamiwazaAppData" -ForegroundColor Yellow
        try {
            Remove-Item -Path $kamiwazaAppData -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully removed Kamiwaza AppData directory" -ForegroundColor Green
        } catch {
            Write-Host "Warning: Could not remove Kamiwaza AppData directory: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Check if there are any remaining WSL distributions
    Write-Host "Checking for remaining WSL distributions..." -ForegroundColor Yellow
    $remainingDistros = @()
    try {
        $wslListAfterOutput = wsl --list --verbose 2>$null
        if ($wslListAfterOutput) {
            $lines = $wslListAfterOutput -split "`n"
            foreach ($line in $lines) {
                $trimmedLine = $line.Trim()
                if ($trimmedLine -and $trimmedLine -notmatch "NAME" -and $trimmedLine -notmatch "----") {
                    $parts = $trimmedLine -split "\s+"
                    if ($parts.Length -gt 0) {
                        $distroName = $parts[0] -replace "\*", ""
                        $distroName = $distroName.Trim()
                        if ($distroName -and $distroName -ne "") {
                            $remainingDistros += $distroName
                        }
                    }
                }
            }
        }
        Write-Verbose "Remaining distributions: $($remainingDistros -join ', ')"
    } catch {
        Write-Verbose "Could not list WSL distributions: $($_.Exception.Message)"
    }
    
    if ($remainingDistros.Count -eq 0) {
        Write-Host "No remaining WSL distributions found - considering WSL feature removal" -ForegroundColor Yellow
        
        $shouldRemoveWSL = $false
        if ($AutoRemoveWSL) {
            $shouldRemoveWSL = $true
            Write-Host "AutoRemoveWSL enabled - will remove WSL feature" -ForegroundColor Yellow
        } elseif (-not $Force) {
            $removeWSL = Read-Host "Would you like to remove the WSL feature entirely? This will require a reboot. (y/N)"
            if ($removeWSL -eq "y" -or $removeWSL -eq "Y") {
                $shouldRemoveWSL = $true
            }
        } else {
            $shouldRemoveWSL = $true
            Write-Host "Force mode enabled - will remove WSL feature" -ForegroundColor Yellow
        }
        
        if ($shouldRemoveWSL) {
            Write-Host "Removing WSL feature..." -ForegroundColor Yellow
            try {
                # Disable WSL feature
                $result = dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "WSL feature disabled successfully" -ForegroundColor Green
                    Write-Host "NOTE: A system reboot is required to complete WSL removal" -ForegroundColor Yellow
                } else {
                    Write-Host "Warning: Could not disable WSL feature" -ForegroundColor Yellow
                }
                
                # Also disable Virtual Machine Platform if present
                $vmResult = dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Virtual Machine Platform feature disabled" -ForegroundColor Green
                }
                
            } catch {
                Write-Host "Warning: Could not remove WSL features: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "Found $($remainingDistros.Count) remaining WSL distribution(s) - keeping WSL feature" -ForegroundColor Green
        Write-Verbose "Remaining distributions: $($remainingDistros -join ', ')"
    }
    
    Write-Host "WSL cleanup completed successfully!" -ForegroundColor Green
    
} catch { 
    Write-Host "Error during WSL cleanup: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Continuing with cleanup..." -ForegroundColor Yellow
}

Write-Host "=== CLEANUP COMPLETE ===" -ForegroundColor Cyan