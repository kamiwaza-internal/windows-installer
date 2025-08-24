# Kamiwaza Repair Mode Test Script
# Tests the MSI installer's repair functionality

param(
    [switch]$Verbose,
    [switch]$SkipInstall,
    [string]$MSIPath = "kamiwaza_installer.msi"
)

Write-Host "=== KAMIWAZA REPAIR MODE TEST ===" -ForegroundColor Cyan
Write-Host ""

# Check if MSI exists
if (-not (Test-Path $MSIPath)) {
    Write-Host "[ERROR] MSI installer not found: $MSIPath" -ForegroundColor Red
    Write-Host "Please run build.bat first to create the MSI installer." -ForegroundColor Yellow
    exit 1
}

Write-Host "[INFO] Found MSI installer: $MSIPath" -ForegroundColor Green
Write-Host ""

# Check if already installed
Write-Host "[INFO] Checking if Kamiwaza is already installed..." -ForegroundColor Yellow
$isInstalled = $false
try {
    $regKey = Get-ItemProperty "HKCU:\Software\Kamiwaza" -ErrorAction SilentlyContinue
    if ($regKey) {
        Write-Host "[INFO] Kamiwaza appears to be already installed" -ForegroundColor Green
        $isInstalled = $true
    } else {
        Write-Host "[INFO] Kamiwaza not installed" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[INFO] Kamiwaza not installed (registry check failed)" -ForegroundColor Yellow
}

Write-Host ""

# Test sequence
if (-not $isInstalled -and -not $SkipInstall) {
    Write-Host "=== STEP 1: FRESH INSTALL ===" -ForegroundColor Cyan
    Write-Host "[INFO] Installing Kamiwaza..." -ForegroundColor Yellow
    
    $installArgs = @("/i", $MSIPath, "/quiet", "/l*v", "$env:TEMP\kamiwaza_install.log")
    if ($Verbose) {
        Write-Host "Install command: msiexec $($installArgs -join ' ')" -ForegroundColor Gray
    }
    
    $installResult = Start-Process -FilePath "msiexec.exe" -ArgumentList $installArgs -Wait -PassThru
    
    if ($installResult.ExitCode -eq 0) {
        Write-Host "[SUCCESS] Installation completed with exit code: $($installResult.ExitCode)" -ForegroundColor Green
        $isInstalled = $true
    } else {
        Write-Host "[ERROR] Installation failed with exit code: $($installResult.ExitCode)" -ForegroundColor Red
        Write-Host "Check logs at: $env:TEMP\kamiwaza_install.log" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host ""
}

# Test repair mode
if ($isInstalled) {
    Write-Host "=== STEP 2: REPAIR MODE TEST ===" -ForegroundColor Cyan
    Write-Host "[INFO] Testing repair mode..." -ForegroundColor Yellow
    
    $repairArgs = @("/f", $MSIPath, "/quiet", "/l*v", "$env:TEMP\kamiwaza_repair.log")
    if ($Verbose) {
        Write-Host "Repair command: msiexec $($repairArgs -join ' ')" -ForegroundColor Gray
    }
    
    $repairResult = Start-Process -FilePath "msiexec.exe" -ArgumentList $repairArgs -Wait -PassThru
    
    if ($repairResult.ExitCode -eq 0) {
        Write-Host "[SUCCESS] Repair mode completed with exit code: $($repairResult.ExitCode)" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Repair mode failed with exit code: $($repairResult.ExitCode)" -ForegroundColor Red
        Write-Host "Check logs at: $env:TEMP\kamiwaza_repair.log" -ForegroundColor Yellow
    }
} else {
    Write-Host "[WARN] Skipping repair test - Kamiwaza not installed" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== VERIFICATION ===" -ForegroundColor Cyan

# Verify custom actions executed
Write-Host "[INFO] Verifying repair mode custom actions..." -ForegroundColor Yellow

# Check WSL instance
Write-Host "[INFO] Checking WSL instances..." -ForegroundColor Yellow
try {
    $wslInstances = wsl --list --quiet 2>$null
    if ($wslInstances -match "kamiwaza") {
        Write-Host "[OK] WSL kamiwaza instance found" -ForegroundColor Green
    } else {
        Write-Host "[WARN] WSL kamiwaza instance not found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARN] Could not check WSL instances" -ForegroundColor Yellow
}

# Check GPU detection scripts
Write-Host "[INFO] Checking GPU detection scripts..." -ForegroundColor Yellow
$gpuScripts = @(
    "$env:LOCALAPPDATA\Kamiwaza\setup_nvidia_gpu.sh",
    "$env:LOCALAPPDATA\Kamiwaza\setup_intel_arc_gpu.sh",
    "$env:LOCALAPPDATA\Kamiwaza\setup_intel_integrated_gpu.sh"
)

foreach ($script in $gpuScripts) {
    if (Test-Path $script) {
        Write-Host "[OK] GPU script found: $(Split-Path $script -Leaf)" -ForegroundColor Green
    }
}

# Check autostart registry entries
Write-Host "[INFO] Checking autostart registry entries..." -ForegroundColor Yellow
try {
    $runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    $autostartEntry = Get-ItemProperty $runOnceKey -Name "KamiwazaGPUAutostart" -ErrorAction SilentlyContinue
    if ($autostartEntry) {
        Write-Host "[OK] Autostart registry entry found" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Autostart registry entry not found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARN] Could not check autostart registry" -ForegroundColor Yellow
}

# Check scheduled tasks
Write-Host "[INFO] Checking scheduled tasks..." -ForegroundColor Yellow
try {
    $task = Get-ScheduledTask -TaskName "KamiwazaAutostart" -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "[OK] Autostart scheduled task found" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Autostart scheduled task not found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[WARN] Could not check scheduled tasks" -ForegroundColor Yellow
}

# Check log files
Write-Host "[INFO] Checking log files..." -ForegroundColor Yellow
$logFiles = @(
    "$env:TEMP\kamiwaza_install.log",
    "$env:TEMP\kamiwaza_repair.log",
    "$env:LOCALAPPDATA\Kamiwaza\logs\kamiwaza_installer.log"
)

foreach ($logFile in $logFiles) {
    if (Test-Path $logFile) {
        $size = (Get-Item $logFile).Length
        Write-Host "[OK] Log file found: $(Split-Path $logFile -Leaf) ($size bytes)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== REPAIR MODE TEST COMPLETE ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test manually:" -ForegroundColor Yellow
Write-Host "1. Open Control Panel > Programs > Programs and Features" -ForegroundColor White
Write-Host "2. Find Kamiwaza and click 'Change'" -ForegroundColor White
Write-Host "3. Select 'Repair' option" -ForegroundColor White
Write-Host "4. Monitor the installation process" -ForegroundColor White
Write-Host ""
Write-Host "To view detailed logs:" -ForegroundColor Yellow
Write-Host "- Install log: $env:TEMP\kamiwaza_install.log" -ForegroundColor White
Write-Host "- Repair log: $env:TEMP\kamiwaza_repair.log" -ForegroundColor White
Write-Host "- AppData logs: $env:LOCALAPPDATA\Kamiwaza\logs\" -ForegroundColor White
Write-Host ""

if ($Verbose) {
    Write-Host "Verbose mode enabled - check console output for detailed information" -ForegroundColor Gray
} 