#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive MSI installation test script
    
.DESCRIPTION
    This script tests the MSI installation process with full logging,
    captures all output, and diagnoses installation issues.
    
.PARAMETER MSIPath
    Path to the MSI installer to test (defaults to kamiwaza_installer.msi)
    
.PARAMETER Clean
    Clean up before testing (uninstall first)
    
.PARAMETER Verbose
    Enable verbose output
    
.EXAMPLE
    .\test_msi_installation.ps1 -Verbose
    
.EXAMPLE
    .\test_msi_installation.ps1 -MSIPath "kamiwaza_installer.msi" -Clean
#>

param(
    [string]$MSIPath = "kamiwaza_installer.msi",
    [switch]$Clean,
    [switch]$Verbose
)

# Enable verbose output if requested
if ($Verbose) {
    $VerbosePreference = "Continue"
}

$ErrorActionPreference = "Continue"

Write-Host "=== KAMIWAZA MSI INSTALLATION TEST ===" -ForegroundColor Cyan
Write-Host "Testing MSI: $MSIPath" -ForegroundColor Yellow

# Create test log directory
$testLogDir = Join-Path $env:TEMP "kamiwaza_test_logs_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $testLogDir -Force | Out-Null
Write-Host "Test logs will be saved to: $testLogDir" -ForegroundColor Green

# Function to capture command output with real-time display
function Invoke-CommandWithLogging {
    param(
        [string]$Command,
        [array]$Arguments = @(),
        [string]$LogFile,
        [string]$Description,
        [int]$TimeoutSeconds = 300
    )
    
    Write-Host "`n--- $Description ---" -ForegroundColor Cyan
    Write-Host "Command: $Command $($Arguments -join ' ')" -ForegroundColor Yellow
    Write-Host "Log file: $LogFile" -ForegroundColor Gray
    
    $fullCommand = "$Command $($Arguments -join ' ')"
    $logPath = Join-Path $testLogDir $LogFile
    
    try {
        # Start the process with output redirection
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $Command
        $processInfo.Arguments = $Arguments -join ' '
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        
        # Event handlers for output
        $outputBuilder = New-Object System.Text.StringBuilder
        $errorBuilder = New-Object System.Text.StringBuilder
        
        $outputHandler = {
            if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
                $line = $EventArgs.Data
                Write-Host $line -ForegroundColor White
                [void]$outputBuilder.AppendLine($line)
            }
        }
        
        $errorHandler = {
            if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
                $line = $EventArgs.Data
                Write-Host $line -ForegroundColor Red
                [void]$errorBuilder.AppendLine($line)
            }
        }
        
        Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action $outputHandler | Out-Null
        Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action $errorHandler | Out-Null
        
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        
        if (-not $completed) {
            Write-Host "Process timed out after $TimeoutSeconds seconds!" -ForegroundColor Red
            $process.Kill()
            return @{ ExitCode = -1; Output = "TIMEOUT"; Error = "Process timed out" }
        }
        
        # Clean up event handlers
        Get-EventSubscriber | Where-Object { $_.SourceObject -eq $process } | Unregister-Event
        
        $exitCode = $process.ExitCode
        $output = $outputBuilder.ToString()
        $error = $errorBuilder.ToString()
        
        # Write to log file
        $logContent = @"
=== $Description ===
Command: $fullCommand
Exit Code: $exitCode
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

=== STDOUT ===
$output

=== STDERR ===
$error

=== END ===
"@
        
        Set-Content -Path $logPath -Value $logContent -Encoding UTF8
        
        Write-Host "Exit Code: $exitCode" -ForegroundColor $(if ($exitCode -eq 0) { "Green" } else { "Red" })
        
        return @{
            ExitCode = $exitCode
            Output = $output
            Error = $error
            LogPath = $logPath
        }
        
    } catch {
        Write-Host "Error executing command: $($_.Exception.Message)" -ForegroundColor Red
        return @{ ExitCode = -2; Output = ""; Error = $_.Exception.Message }
    }
}

# Function to check system state
function Check-SystemState {
    param([string]$Phase)
    
    Write-Host "`n=== SYSTEM STATE CHECK: $Phase ===" -ForegroundColor Magenta
    
    # Check WSL instances
    Write-Host "WSL Instances:" -ForegroundColor Yellow
    try {
        $wslResult = Invoke-CommandWithLogging -Command "wsl" -Arguments @("--list", "--quiet") -LogFile "wsl_list_$Phase.log" -Description "WSL List" -TimeoutSeconds 30
        if ($wslResult.Output) {
            $instances = $wslResult.Output -split "`n" | Where-Object { $_.Trim() -ne "" }
            foreach ($instance in $instances) {
                Write-Host "  - $($instance.Trim())" -ForegroundColor White
            }
            
            # Check for kamiwaza instances specifically
            $kamiwazaInstances = $instances | Where-Object { $_ -match "kamiwaza" }
            if ($kamiwazaInstances) {
                Write-Host "Found Kamiwaza instances:" -ForegroundColor Green
                foreach ($ki in $kamiwazaInstances) {
                    Write-Host "  - $($ki.Trim())" -ForegroundColor Green
                }
            } else {
                Write-Host "No Kamiwaza WSL instances found" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "Error checking WSL: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Check AppData Kamiwaza directory
    Write-Host "`nKamiwaza AppData Directory:" -ForegroundColor Yellow
    $kamiwazaAppData = Join-Path $env:LOCALAPPDATA "Kamiwaza"
    if (Test-Path $kamiwazaAppData) {
        Write-Host "  Directory exists: $kamiwazaAppData" -ForegroundColor Green
        try {
            $items = Get-ChildItem -Path $kamiwazaAppData -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Contents ($($items.Count) items):" -ForegroundColor White
            foreach ($item in $items | Select-Object -First 20) {
                $type = if ($item.PSIsContainer) { "DIR" } else { "FILE" }
                Write-Host "    $type : $($item.FullName.Replace($kamiwazaAppData, '.'))" -ForegroundColor Gray
            }
            if ($items.Count -gt 20) {
                Write-Host "    ... and $($items.Count - 20) more items" -ForegroundColor Gray
            }
        } catch {
            Write-Host "  Error reading contents: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  Directory does not exist: $kamiwazaAppData" -ForegroundColor Yellow
    }
    
    # Check WSL data directory
    Write-Host "`nWSL Data Directory:" -ForegroundColor Yellow
    $wslDataPath = Join-Path $env:LOCALAPPDATA "WSL\kamiwaza"
    if (Test-Path $wslDataPath) {
        Write-Host "  Directory exists: $wslDataPath" -ForegroundColor Green
        try {
            $size = (Get-ChildItem -Path $wslDataPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            Write-Host "  Size: $([math]::Round($size / 1MB, 2)) MB" -ForegroundColor White
        } catch {
            Write-Host "  Error calculating size: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  Directory does not exist: $wslDataPath" -ForegroundColor Yellow
    }
    
    Write-Host "=== END SYSTEM STATE CHECK ===" -ForegroundColor Magenta
}

try {
    # Initial system state
    Check-SystemState -Phase "BEFORE"
    
    # Clean up if requested
    if ($Clean) {
        Write-Host "`n=== CLEANUP PHASE ===" -ForegroundColor Red
        
        # Uninstall via MSI
        Write-Host "Attempting to uninstall via MSI..." -ForegroundColor Yellow
        $uninstallResult = Invoke-CommandWithLogging -Command "msiexec" -Arguments @("/x", $MSIPath, "/quiet", "/l*v", (Join-Path $testLogDir "uninstall.log")) -LogFile "uninstall_output.log" -Description "MSI Uninstall" -TimeoutSeconds 120
        
        # Also try via Windows Features if that doesn't work
        Write-Host "Checking installed programs..." -ForegroundColor Yellow
        try {
            $installedPrograms = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Kamiwaza*" }
            if ($installedPrograms) {
                foreach ($program in $installedPrograms) {
                    Write-Host "Found installed program: $($program.Name)" -ForegroundColor Yellow
                    Write-Host "Attempting to uninstall..." -ForegroundColor Yellow
                    $program.Uninstall() | Out-Null
                }
            }
        } catch {
            Write-Host "Error checking installed programs: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Manual cleanup using PowerShell script if it exists
        $cleanupScript = "cleanup_wsl_kamiwaza.ps1"
        if (Test-Path $cleanupScript) {
            Write-Host "Running cleanup script..." -ForegroundColor Yellow
            $cleanupResult = Invoke-CommandWithLogging -Command "powershell" -Arguments @("-ExecutionPolicy", "Bypass", "-File", $cleanupScript, "-Force", "-Verbose") -LogFile "cleanup_output.log" -Description "Cleanup Script" -TimeoutSeconds 120
        }
        
        Start-Sleep -Seconds 5
        Check-SystemState -Phase "AFTER_CLEANUP"
    }
    
    # Verify MSI exists
    if (-not (Test-Path $MSIPath)) {
        Write-Host "ERROR: MSI file not found: $MSIPath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "`nMSI file found: $MSIPath" -ForegroundColor Green
    $msiInfo = Get-ItemProperty -Path $MSIPath
    Write-Host "MSI size: $([math]::Round($msiInfo.Length / 1MB, 2)) MB" -ForegroundColor White
    Write-Host "MSI modified: $($msiInfo.LastWriteTime)" -ForegroundColor White
    
    # Install MSI with comprehensive logging
    Write-Host "`n=== INSTALLATION PHASE ===" -ForegroundColor Green
    
    $msiLogFile = Join-Path $testLogDir "msi_install.log"
    $installArgs = @(
        "/i", $MSIPath,
        "/l*v", $msiLogFile,
        "/quiet"
    )
    
    Write-Host "Installing MSI with verbose logging..." -ForegroundColor Yellow
    $installResult = Invoke-CommandWithLogging -Command "msiexec" -Arguments $installArgs -LogFile "install_output.log" -Description "MSI Installation" -TimeoutSeconds 600
    
    Write-Host "`nInstallation completed with exit code: $($installResult.ExitCode)" -ForegroundColor $(if ($installResult.ExitCode -eq 0) { "Green" } else { "Red" })
    
    # Wait a moment for any background processes
    Write-Host "Waiting for background processes to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # Check system state after installation
    Check-SystemState -Phase "AFTER_INSTALL"
    
    # Try to manually run the installer script to see what happens
    Write-Host "`n=== MANUAL SCRIPT TEST ===" -ForegroundColor Cyan
    
    # Look for the installer script in common locations
    $possiblePaths = @(
        "C:\Program Files\Kamiwaza\kamiwaza_headless_installer.py",
        "C:\Program Files (x86)\Kamiwaza\kamiwaza_headless_installer.py",
        "$env:LOCALAPPDATA\Kamiwaza\kamiwaza_headless_installer.py",
        "$env:TEMP\Kamiwaza\kamiwaza_headless_installer.py"
    )
    
    $installerScript = $null
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $installerScript = $path
            Write-Host "Found installer script: $path" -ForegroundColor Green
            break
        }
    }
    
    if ($installerScript) {
        Write-Host "Attempting to run installer script manually..." -ForegroundColor Yellow
        $scriptResult = Invoke-CommandWithLogging -Command "python" -Arguments @($installerScript) -LogFile "manual_script_output.log" -Description "Manual Script Execution" -TimeoutSeconds 600
        
        Write-Host "Manual script execution completed with exit code: $($scriptResult.ExitCode)" -ForegroundColor $(if ($scriptResult.ExitCode -eq 0) { "Green" } else { "Red" })
    } else {
        Write-Host "Could not find installer script in any expected location" -ForegroundColor Red
        Write-Host "Searched paths:" -ForegroundColor Yellow
        foreach ($path in $possiblePaths) {
            Write-Host "  - $path" -ForegroundColor Gray
        }
    }
    
    # Check final system state
    Check-SystemState -Phase "FINAL"
    
    # Summary
    Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Cyan
    Write-Host "MSI Installation Exit Code: $($installResult.ExitCode)" -ForegroundColor $(if ($installResult.ExitCode -eq 0) { "Green" } else { "Red" })
    if ($scriptResult) {
        Write-Host "Manual Script Exit Code: $($scriptResult.ExitCode)" -ForegroundColor $(if ($scriptResult.ExitCode -eq 0) { "Green" } else { "Red" })
    }
    Write-Host "Test logs saved to: $testLogDir" -ForegroundColor Green
    Write-Host "Key log files:" -ForegroundColor Yellow
    Write-Host "  - MSI Installation: $msiLogFile" -ForegroundColor White
    Write-Host "  - Install Output: $(Join-Path $testLogDir 'install_output.log')" -ForegroundColor White
    if ($scriptResult) {
        Write-Host "  - Manual Script: $(Join-Path $testLogDir 'manual_script_output.log')" -ForegroundColor White
    }
    
} catch {
    Write-Host "ERROR during testing: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
} finally {
    Write-Host "`n=== TEST COMPLETED ===" -ForegroundColor Cyan
    Write-Host "Check the logs in $testLogDir for detailed analysis" -ForegroundColor Green
}