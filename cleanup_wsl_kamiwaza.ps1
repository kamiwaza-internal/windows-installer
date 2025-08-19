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
    $wslListOutput = wsl --list --verbose 2>$null
    
    # Parse the verbose output to find distributions containing "kamiwaza"
    $kamiwazaInstances = @()
    
    if ($wslListOutput) {
        Write-Verbose "WSL list output:"
        Write-Verbose ($wslListOutput -join "`n")
        
        # Convert to string and split by lines
        $outputString = $wslListOutput -join "`n"
        $lines = $outputString -split "`r?`n"
        
        Write-Verbose "Parsing $($lines.Count) lines..."
        
        foreach ($line in $lines) {
            $trimmedLine = $line.Trim()
            Write-Verbose "Processing line: '$trimmedLine'"
            
            # Skip empty lines and header
            if ($trimmedLine -eq "" -or $trimmedLine -match "^\s*NAME\s+STATE\s+VERSION") {
                Write-Verbose "Skipping line: '$trimmedLine'"
                continue
            }
            
            # Extract the first word (distribution name) from the line
            # Handle both "* distribution_name" and "distribution_name" formats
            $words = $trimmedLine -split "\s+" | Where-Object { $_.Trim() -ne "" }
            
            if ($words.Count -ge 1) {
                # If first word is "*", take the second word
                $distName = if ($words[0] -eq "*") { $words[1] } else { $words[0] }
                Write-Verbose "Extracted distribution name: '$distName'"
                
                # Check if the distribution name contains "kamiwaza" (case insensitive)
                Write-Verbose "Checking if '$distName' contains 'kamiwaza' (case insensitive)"
                Write-Verbose "Length of distName: $($distName.Length)"
                
                # Use simple string comparison methods
                $distNameLower = $distName.ToLower()
                $kamiwazaLower = "kamiwaza"
                
                Write-Verbose "Comparing '$distNameLower' with '$kamiwazaLower'"
                
                if ($distNameLower -eq $kamiwazaLower) {
                    Write-Verbose "EXACT MATCH FOUND! Adding '$distName' to kamiwaza instances"
                    $kamiwazaInstances += $distName
                    Write-Host "Found Kamiwaza WSL instance: $distName" -ForegroundColor Green
                } elseif ($distNameLower -like "*$kamiwazaLower*") {
                    Write-Verbose "CONTAINS MATCH FOUND! Adding '$distName' to kamiwaza instances"
                    $kamiwazaInstances += $distName
                    Write-Host "Found Kamiwaza WSL instance: $distName" -ForegroundColor Green
                } else {
                    Write-Verbose "No match for '$distName'"
                }
            }
        }
    }
    
    if ($kamiwazaInstances.Count -eq 0) {
        Write-Host "No Kamiwaza WSL instances found" -ForegroundColor Yellow
    } else {
        Write-Host "Found $($kamiwazaInstances.Count) Kamiwaza WSL instance(s) to clean up: $($kamiwazaInstances -join ', ')" -ForegroundColor Yellow
        
        # Stop and unregister each kamiwaza instance
        foreach ($instance in $kamiwazaInstances) {
            Write-Host "Processing WSL instance: $instance" -ForegroundColor Cyan
            
            # Validate instance name
            if ([string]::IsNullOrWhiteSpace($instance)) {
                Write-Host "Warning: Empty instance name, skipping" -ForegroundColor Yellow
                continue
            }
            
            try {
                # Clean the instance name to remove any hidden characters
                $cleanInstance = $instance.Trim()
                Write-Verbose "Cleaned instance name: '$cleanInstance' (length: $($cleanInstance.Length))"
                
                # Stop the instance first
                Write-Verbose "Stopping WSL instance: '$cleanInstance'"
                $terminateResult = & wsl --terminate $cleanInstance 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Successfully terminated WSL instance: $cleanInstance" -ForegroundColor Green
                } else {
                    Write-Verbose "Could not terminate $cleanInstance - $terminateResult"
                    # Try alternative termination method
                    Write-Verbose "Trying alternative termination method..."
                    $altTerminateResult = & wsl --shutdown 2>&1
                    Start-Sleep -Seconds 2
                }
                Start-Sleep -Seconds 3
                
                # IMPORTANT: Remove kamiwaza package BEFORE unregistering the instance
                Write-Host "Removing Kamiwaza package from WSL instance: $cleanInstance" -ForegroundColor Yellow
                Write-Verbose "Running: wsl -d $cleanInstance sudo apt remove --purge -y kamiwaza"
                
                # Try to remove kamiwaza package if instance is still accessible
                $removeResult = & wsl -d $cleanInstance sudo apt remove --purge -y kamiwaza 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Successfully removed kamiwaza package from $cleanInstance" -ForegroundColor Green
                } else {
                    Write-Host "Warning: Could not remove kamiwaza package from $cleanInstance (may not be installed or instance not accessible)" -ForegroundColor Yellow
                    Write-Verbose "Remove command output: $removeResult"
                    
                    # Try alternative package removal methods
                    Write-Verbose "Trying alternative package removal methods..."
                    
                    # Try with dpkg directly
                    $dpkgResult = & wsl -d $cleanInstance sudo dpkg --remove --force-all kamiwaza 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "Successfully removed kamiwaza package using dpkg from $cleanInstance" -ForegroundColor Green
                    } else {
                        Write-Verbose "dpkg removal also failed: $dpkgResult"
                        
                        # Try to clean up any remaining files manually
                        Write-Verbose "Attempting manual cleanup of kamiwaza files..."
                        $manualCleanupResult = & wsl -d $cleanInstance sudo find /usr -name "*kamiwaza*" -delete 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "Manually cleaned up some kamiwaza files from $cleanInstance" -ForegroundColor Green
                        } else {
                            Write-Verbose "Manual cleanup failed: $manualCleanupResult"
                        }
                    }
                }
                
                # Also try to remove any remaining kamiwaza-related packages
                Write-Verbose "Checking for other kamiwaza-related packages..."
                $relatedPackages = & wsl -d $cleanInstance dpkg -l | Select-String "kamiwaza" 2>$null
                if ($relatedPackages) {
                    Write-Host "Found additional kamiwaza-related packages, attempting removal..." -ForegroundColor Yellow
                    foreach ($package in $relatedPackages) {
                        $pkgName = ($package -split "\s+")[1]
                        if ($pkgName -and $pkgName -like "*kamiwaza*") {
                            Write-Verbose "Removing related package: $pkgName"
                            & wsl -d $cleanInstance sudo apt remove --purge -y $pkgName 2>$null
                        }
                    }
                }
                
                Start-Sleep -Seconds 2
                
                # Now unregister the instance completely
                Write-Verbose "Unregistering WSL instance: $cleanInstance"
                $unregisterResult = & wsl --unregister $cleanInstance 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Successfully unregistered: $cleanInstance" -ForegroundColor Green
                } else {
                    Write-Host "Warning: Could not unregister $cleanInstance - $unregisterResult" -ForegroundColor Yellow
                    
                    # Try alternative unregister method
                    Write-Verbose "Trying alternative unregister method..."
                    $altUnregisterResult = & wsl --unregister $cleanInstance 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "Successfully unregistered: $cleanInstance" -ForegroundColor Green
                    } else {
                        Write-Host "Warning: Alternative unregister also failed: $altUnregisterResult" -ForegroundColor Yellow
                    }
                }
                
            } catch {
                Write-Host "Warning: Could not fully clean up $cleanInstance - attempting force unregister" -ForegroundColor Yellow
                try {
                    $forceResult = & wsl --unregister $cleanInstance 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "Force unregistered: $cleanInstance" -ForegroundColor Green
                    } else {
                        Write-Host "Error: Could not unregister $cleanInstance - $forceResult" -ForegroundColor Red
                        
                        # Final attempt with shutdown and unregister
                        Write-Verbose "Final attempt: shutting down WSL and then unregistering..."
                        & wsl --shutdown 2>$null
                        Start-Sleep -Seconds 3
                        $finalResult = & wsl --unregister $cleanInstance 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "Successfully unregistered $cleanInstance after WSL shutdown" -ForegroundColor Green
                        } else {
                            Write-Host "Error: Final unregister attempt failed: $finalResult" -ForegroundColor Red
                        }
                    }
                } catch {
                    Write-Host "Error: Could not unregister $cleanInstance - $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
    
    # Clean up WSL data directory for kamiwaza
    $wslDataPath = Join-Path $env:LOCALAPPDATA "WSL\kamiwaza"
    if (Test-Path $wslDataPath) {
        Write-Host "Removing WSL data directory: $wslDataPath" -ForegroundColor Yellow
        
        # First, try to stop any running WSL processes that might be using the VHDX
        Write-Verbose "Stopping any running WSL processes..."
        try {
            # Stop WSL completely
            & wsl --shutdown 2>$null
            Start-Sleep -Seconds 3
            
            # Force stop any remaining WSL processes
            Get-Process -Name "wsl" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Get-Process -Name "wslhost" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Get-Process -Name "wslservice" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        } catch {
            Write-Verbose "Could not stop WSL processes: $($_.Exception.Message)"
        }
        
        # Try multiple cleanup attempts
        $cleanupAttempts = 0
        $maxAttempts = 3
        
        do {
            $cleanupAttempts++
            Write-Verbose "Cleanup attempt $cleanupAttempts of $maxAttempts"
            
            try {
                # Try to remove the directory
                Remove-Item -Path $wslDataPath -Recurse -Force -ErrorAction Stop
                Write-Host "Successfully removed WSL data directory" -ForegroundColor Green
                break
            } catch {
                Write-Host "Warning: Attempt $cleanupAttempts failed to remove WSL data directory: $($_.Exception.Message)" -ForegroundColor Yellow
                
                if ($cleanupAttempts -lt $maxAttempts) {
                    # If the main directory can't be removed, try to remove individual files
                    Write-Verbose "Attempting to remove individual files from WSL data directory..."
                    try {
                        Get-ChildItem -Path $wslDataPath -Recurse -Force | ForEach-Object {
                            try {
                                Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                            } catch {
                                Write-Verbose "Could not remove file: $($_.FullName)"
                            }
                        }
                        
                        # Try to remove the directory again
                        Remove-Item -Path $wslDataPath -Force -ErrorAction SilentlyContinue
                        if (-not (Test-Path $wslDataPath)) {
                            Write-Host "Successfully removed WSL data directory after individual file cleanup" -ForegroundColor Green
                            break
                        } else {
                            Write-Host "Warning: Some files in WSL data directory could not be removed" -ForegroundColor Yellow
                        }
                    } catch {
                        Write-Host "Warning: Could not perform individual file cleanup: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                    
                    # Wait before next attempt
                    Start-Sleep -Seconds 2
                } else {
                    Write-Host "Error: Failed to remove WSL data directory after $maxAttempts attempts" -ForegroundColor Red
                }
            }
        } while ($cleanupAttempts -lt $maxAttempts -and (Test-Path $wslDataPath))
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
    
    # Remove entire Kamiwaza AppData directory
    $kamiwazaAppDataFull = Join-Path $env:LOCALAPPDATA "Kamiwaza"
    if (Test-Path $kamiwazaAppDataFull) {
        Write-Host "Removing entire Kamiwaza AppData directory: $kamiwazaAppDataFull" -ForegroundColor Yellow
        try {
            Remove-Item -Path $kamiwazaAppDataFull -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully removed entire Kamiwaza AppData directory" -ForegroundColor Green
        } catch {
            Write-Host "Warning: Could not remove entire Kamiwaza AppData directory: $($_.Exception.Message)" -ForegroundColor Yellow
            
            # Try alternative method using cmd.exe
            Write-Verbose "Trying alternative removal method using cmd.exe..."
            try {
                $cmdResult = & cmd.exe /c "rmdir /s /q `"$kamiwazaAppDataFull`" >nul 2>&1"
                if (-not (Test-Path $kamiwazaAppDataFull)) {
                    Write-Host "Successfully removed Kamiwaza AppData directory using cmd.exe" -ForegroundColor Green
                } else {
                    Write-Host "Warning: Could not remove Kamiwaza AppData directory even with cmd.exe" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Warning: Alternative removal method also failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Verbose "Kamiwaza AppData directory not found: $kamiwazaAppDataFull"
    }
    
    # Clean up registry entries
    Write-Host "Cleaning up registry entries..." -ForegroundColor Yellow
    try {
        $registryKeys = @(
            "HKCU:\Software\Kamiwaza",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
        )
        
        foreach ($regKey in $registryKeys) {
            if (Test-Path $regKey) {
                Write-Host "Checking registry key: $regKey" -ForegroundColor Yellow
                
                # Remove Kamiwaza-specific RunOnce entries
                if ($regKey -like "*RunOnce*") {
                    try {
                        $runOnceEntries = Get-ItemProperty -Path $regKey -ErrorAction SilentlyContinue | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -like "*Kamiwaza*" }
                        if ($runOnceEntries) {
                            foreach ($entry in $runOnceEntries) {
                                Write-Host "Removing RunOnce entry: $($entry.Name)" -ForegroundColor Yellow
                                Remove-ItemProperty -Path $regKey -Name $entry.Name -ErrorAction SilentlyContinue
                            }
                        }
                    } catch {
                        Write-Verbose "Could not check RunOnce entries: $($_.Exception.Message)"
                    }
                }
                
                # Remove entire Kamiwaza registry key if it exists
                if ($regKey -like "*Kamiwaza*") {
                    Write-Host "Removing registry key: $regKey" -ForegroundColor Yellow
                    Remove-Item -Path $regKey -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host "Successfully removed registry key: $regKey" -ForegroundColor Green
                }
            }
        }
    } catch {
        Write-Host "Warning: Could not clean up registry entries: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Clean up Start Menu shortcuts
    Write-Host "Cleaning up Start Menu shortcuts..." -ForegroundColor Yellow
    try {
        $startMenuPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Kamiwaza"
        if (Test-Path $startMenuPath) {
            Write-Host "Removing Start Menu shortcuts: $startMenuPath" -ForegroundColor Yellow
            Remove-Item -Path $startMenuPath -Recurse -Force -ErrorAction Stop
            Write-Host "Successfully removed Start Menu shortcuts" -ForegroundColor Green
        } else {
            Write-Verbose "Start Menu shortcuts directory not found: $startMenuPath"
        }
    } catch {
        Write-Host "Warning: Could not remove Start Menu shortcuts: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Clean up Desktop shortcuts if they exist
    Write-Host "Cleaning up Desktop shortcuts..." -ForegroundColor Yellow
    try {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $kamiwazaShortcuts = Get-ChildItem -Path $desktopPath -Filter "*Kamiwaza*" -ErrorAction SilentlyContinue
        if ($kamiwazaShortcuts) {
            foreach ($shortcut in $kamiwazaShortcuts) {
                Write-Host "Removing Desktop shortcut: $($shortcut.Name)" -ForegroundColor Yellow
                Remove-Item -Path $shortcut.FullName -Force -ErrorAction SilentlyContinue
            }
            Write-Host "Successfully removed Desktop shortcuts" -ForegroundColor Green
        } else {
            Write-Verbose "No Kamiwaza Desktop shortcuts found"
        }
    } catch {
        Write-Host "Warning: Could not remove Desktop shortcuts: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host "WSL cleanup completed successfully!" -ForegroundColor Green
    
} catch { 
    Write-Host "Error during WSL cleanup: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Continuing with cleanup..." -ForegroundColor Yellow
}

Write-Host "=== CLEANUP COMPLETE ===" -ForegroundColor Cyan