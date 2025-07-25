param(
    [string]$MSIPath = "installer.msi"
)

Write-Host "=== Kamiwaza MSI Installer Test ===" -ForegroundColor Cyan
Write-Host ""

# Test prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow
$canDownload = $true
try {
    $testUrl = "https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/kamiwaza_installer_0.5.0-rc1_amd64_build35.exe"
    Write-Host "Testing download URL: $testUrl"
    $response = Invoke-WebRequest -Uri $testUrl -Method Head -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Download URL is accessible (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "✗ Download URL test failed: $($_.Exception.Message)" -ForegroundColor Red
    $canDownload = $false
}

# Check PowerShell execution policy
$executionPolicy = Get-ExecutionPolicy
Write-Host "PowerShell Execution Policy: $executionPolicy"
if ($executionPolicy -eq "Restricted") {
    Write-Host "⚠ Warning: PowerShell execution policy is Restricted. This may cause issues." -ForegroundColor Yellow
}

Write-Host ""

# Install with logging
$logFile = "msi_detailed_log.txt"
Write-Host "Installing MSI with detailed logging..." -ForegroundColor Yellow
Write-Host "Log file: $logFile"

# Using perUser scope in WiX, no need for ALLUSERS parameter
$installArgs = @("/i", $MSIPath, "/l*v", $logFile, "/quiet")
$process = Start-Process -FilePath "msiexec" -ArgumentList $installArgs -Wait -PassThru

Write-Host ""
if ($process.ExitCode -eq 0) {
    Write-Host "✓ MSI installation completed successfully" -ForegroundColor Green
    
    # Check installed files (now in LocalAppData for per-user install)
    $installDir = "$env:LOCALAPPDATA\Kamiwaza"
    $exePath = Join-Path $installDir "kamiwaza_installer.exe"
    
    if (Test-Path $exePath) {
        Write-Host "✓ kamiwaza_installer.exe found at: $exePath" -ForegroundColor Green
        $fileInfo = Get-Item $exePath
        Write-Host "  File size: $($fileInfo.Length) bytes"
        Write-Host "  Created: $($fileInfo.CreationTime)"
    } else {
        Write-Host "✗ kamiwaza_installer.exe NOT found in install directory" -ForegroundColor Red
    }
    
    # Check shortcuts
    $startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Kamiwaza"
    if (Test-Path $startMenuPath) {
        Write-Host "✓ Start Menu shortcuts created" -ForegroundColor Green
    } else {
        Write-Host "✗ Start Menu shortcuts NOT found" -ForegroundColor Red
    }
    
} else {
    Write-Host "✗ MSI installation failed with exit code: $($process.ExitCode)" -ForegroundColor Red
    
    # Parse log for common errors
    if (Test-Path $logFile) {
        Write-Host ""
        Write-Host "Analyzing log file for errors..." -ForegroundColor Yellow
        
        $logContent = Get-Content $logFile
        $errors = $logContent | Where-Object { $_ -match "Error|Failed|Exception" }
        
        if ($errors) {
            Write-Host "Found errors in log:" -ForegroundColor Red
            $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        }
        
        # Look for custom action failures
        $customActionErrors = $logContent | Where-Object { $_ -match "DownloadKamiwazaExe" }
        if ($customActionErrors) {
            Write-Host ""
            Write-Host "Custom Action (Download) related entries:" -ForegroundColor Yellow
            $customActionErrors | ForEach-Object { Write-Host "  $_" }
        }
    }
}

Write-Host ""
Write-Host "Full installation log saved to: $logFile" -ForegroundColor Cyan
Write-Host "Test completed." -ForegroundColor Cyan 