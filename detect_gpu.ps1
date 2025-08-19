# GPU Detection Script for Kamiwaza Installer
# Detects GPU types and configures appropriate acceleration scripts in WSL
# Runs non-interactively for MSI installer automation

param(
    [string]$WSLDistribution = "kamiwaza"
)

function Write-LogMessage {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN"  { "Yellow" }
            "INFO"  { "Green" }
            default { "White" }
        }
    )
}

Write-LogMessage "Starting GPU detection for Kamiwaza..."

# Get GPU information with enhanced detection
try {
    Write-LogMessage "Detecting installed graphics cards..."
    
    # Get more detailed GPU information
    $gpus = Get-CimInstance Win32_VideoController | Select-Object Name, AdapterCompatibility, DeviceID, PNPDeviceID, DriverVersion, VideoProcessor
    
    Write-LogMessage "Found graphics controllers:"
    $gpus | ForEach-Object {
        Write-LogMessage "  Name: $($_.Name)"
        Write-LogMessage "  Compatibility: $($_.AdapterCompatibility)"
        Write-LogMessage "  Device ID: $($_.DeviceID)"
        Write-LogMessage "  PNP Device ID: $($_.PNPDeviceID)"
        Write-LogMessage "  Driver Version: $($_.DriverVersion)"
        Write-LogMessage "  Video Processor: $($_.VideoProcessor)"
        Write-LogMessage "  ---"
    }
    
    # Enhanced GPU detection with more specific patterns
    $nvidiaRTX = $gpus | Where-Object { 
        $_.Name -like "*NVIDIA GeForce RTX*" -or 
        $_.Name -like "*NVIDIA RTX*" -or
        $_.Name -like "*GeForce RTX*" -or
        ($_.Name -like "*NVIDIA*" -and $_.Name -like "*RTX*")
    }
    
    $intelArc = $gpus | Where-Object { 
        $_.Name -like "*Intel(R) Arc(TM)*" -or 
        $_.Name -like "*Intel Arc*" -or
        $_.Name -like "*Arc(TM)*" -or
        ($_.Name -like "*Intel*" -and $_.Name -like "*Arc*")
    }
    
    $intelIntegrated = $gpus | Where-Object { 
        $_.Name -like "*Intel(R) UHD*" -or 
        $_.Name -like "*Intel(R) HD*" -or 
        $_.Name -like "*Intel(R) Iris*" -or
        $_.Name -like "*Intel UHD*" -or
        $_.Name -like "*Intel HD*" -or
        $_.Name -like "*Intel Iris*" -or
        ($_.Name -like "*Intel*" -and ($_.Name -like "*UHD*" -or $_.Name -like "*HD*" -or $_.Name -like "*Iris*"))
    }
    
    # Additional validation: Check if we're in a remote/VM environment
    Write-LogMessage "Checking system environment..."
    $isRemote = $false
    $isVM = $false
    
    try {
        # Check for remote desktop services
        $rdpServices = Get-Service -Name "TermService" -ErrorAction SilentlyContinue
        if ($rdpServices -and $rdpServices.Status -eq "Running") {
            Write-LogMessage "Remote Desktop Services detected - this may be a remote session" "WARN"
            $isRemote = $true
        }
        
        # Check for VM indicators
        $vmIndicators = @(
            "VMware",
            "VirtualBox", 
            "Hyper-V",
            "QEMU",
            "Xen",
            "Parallels"
        )
        
        $computerSystem = Get-CimInstance Win32_ComputerSystem
        $manufacturer = $computerSystem.Manufacturer
        $model = $computerSystem.Model
        
        Write-LogMessage "System Manufacturer: $manufacturer"
        Write-LogMessage "System Model: $model"
        
        foreach ($indicator in $vmIndicators) {
            if ($manufacturer -like "*$indicator*" -or $model -like "*$indicator*") {
                Write-LogMessage "Virtual machine detected: $indicator" "WARN"
                $isVM = $true
                break
            }
        }
        
        # Check for WSL-specific environment
        $wslEnv = $env:WSL_DISTRO_NAME
        if ($wslEnv) {
            Write-LogMessage "WSL environment detected: $wslEnv"
        }
        
    } catch {
        Write-LogMessage "Could not determine system environment: $($_.Exception.Message)" "WARN"
    }
    
    # Validate GPU detection against system environment
    Write-LogMessage "Validating GPU detection results..."
    
    if ($nvidiaRTX) {
        Write-LogMessage "NVIDIA GeForce RTX GPU detected!" "INFO"
        
        # Additional validation for NVIDIA
        if ($isRemote -or $isVM) {
            Write-LogMessage "WARNING: Remote/VM environment detected - NVIDIA GPU may not be accessible" "WARN"
            Write-LogMessage "GPU acceleration may not work properly in this environment" "WARN"
        }
        
        # Verify NVIDIA drivers are actually working
        try {
            $nvidiaDriver = Get-Process -Name "nvcontainer" -ErrorAction SilentlyContinue
            if ($nvidiaDriver) {
                Write-LogMessage "NVIDIA container process detected - drivers appear to be working" "INFO"
            } else {
                Write-LogMessage "WARNING: NVIDIA container process not found - drivers may not be working" "WARN"
            }
        } catch {
            Write-LogMessage "Could not verify NVIDIA driver status" "WARN"
        }
        
        Write-LogMessage "Setting up NVIDIA GPU acceleration in WSL..."
        
        # Copy our maintained NVIDIA script into WSL and execute it
        try {
            $scriptSrc = Join-Path $PSScriptRoot "setup_nvidia_gpu.sh"
            if (-not (Test-Path $scriptSrc)) { 
                throw "setup_nvidia_gpu.sh not found at $scriptSrc" 
            }
            
            Write-LogMessage "Found NVIDIA setup script at: $scriptSrc"
            
            # Get absolute path and convert to WSL path
            $absolutePath = (Resolve-Path $scriptSrc).Path
            $wslPath = "/mnt/" + $absolutePath.Replace(":", "").Replace("\", "/").ToLower()
            
            Write-LogMessage "WSL path: $wslPath"
            
            wsl -d $WSLDistribution -- sudo mkdir -p /usr/local/bin
            wsl -d $WSLDistribution -- bash -c "cat '$wslPath' | sed 's/\r$//' | sudo tee /usr/local/bin/setup_nvidia_gpu.sh >/dev/null"
            wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/setup_nvidia_gpu.sh
            
            Write-LogMessage "Copied setup_nvidia_gpu.sh into WSL: /usr/local/bin/setup_nvidia_gpu.sh"
            
            # Execute the script as kamiwaza user
            Write-LogMessage "Executing NVIDIA GPU setup as kamiwaza user..."
            wsl -d $WSLDistribution -- sudo -u kamiwaza /usr/local/bin/setup_nvidia_gpu.sh
        } catch {
            Write-LogMessage "Failed to set up NVIDIA GPU: $($_.Exception.Message)" "ERROR"
        }
    }
    
    if ($intelArc) {
        Write-LogMessage "Intel Arc GPU detected!" "INFO"
        Write-LogMessage "Setting up Intel Arc GPU acceleration in WSL..."
        
        # Copy our maintained Intel Arc script into WSL and execute it
        try {
            $scriptSrc = Join-Path $PSScriptRoot "setup_intel_arc_gpu.sh"
            if (-not (Test-Path $scriptSrc)) { 
                throw "setup_intel_arc_gpu.sh not found at $scriptSrc" 
            }
            
            Write-LogMessage "Found Intel Arc setup script at: $scriptSrc"
            
            # Get absolute path and convert to WSL path
            $absolutePath = (Resolve-Path $scriptSrc).Path
            $wslPath = "/mnt/" + $absolutePath.Replace(":", "").Replace("\", "/").ToLower()
            
            Write-LogMessage "WSL path: $wslPath"
            
            wsl -d $WSLDistribution -- sudo mkdir -p /usr/local/bin
            wsl -d $WSLDistribution -- bash -c "cat '$wslPath' | sed 's/\r$//' | sudo tee /usr/local/bin/setup_intel_arc_gpu.sh >/dev/null"
            wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/setup_intel_arc_gpu.sh
            
            Write-LogMessage "Copied setup_intel_arc_gpu.sh into WSL: /usr/local/bin/setup_intel_arc_gpu.sh"
            
            # Execute the script as kamiwaza user
            Write-LogMessage "Executing Intel Arc GPU setup as kamiwaza user..."
            wsl -d $WSLDistribution -- sudo -u kamiwaza /usr/local/bin/setup_intel_arc_gpu.sh
        } catch {
            Write-LogMessage "Failed to set up Intel Arc GPU: $($_.Exception.Message)" "ERROR"
        }
    }
    
    if ($intelIntegrated) {
        Write-LogMessage "Intel Integrated Graphics detected!" "INFO"
        Write-LogMessage "Setting up Intel Integrated Graphics acceleration in WSL..."
        
        # Copy our maintained Intel Integrated script into WSL and execute it
        try {
            $scriptSrc = Join-Path $PSScriptRoot "setup_intel_integrated_gpu.sh"
            if (-not (Test-Path $scriptSrc)) { 
                throw "setup_intel_integrated_gpu.sh not found at $scriptSrc" 
            }
            
            Write-LogMessage "Found Intel Integrated setup script at: $scriptSrc"
            
            # Get absolute path and convert to WSL path
            $absolutePath = (Resolve-Path $scriptSrc).Path
            $wslPath = "/mnt/" + $absolutePath.Replace(":", "").Replace("\", "/").ToLower()
            
            Write-LogMessage "WSL path: $wslPath"
            
            wsl -d $WSLDistribution -- sudo mkdir -p /usr/local/bin
            wsl -d $WSLDistribution -- bash -c "cat '$wslPath' | sed 's/\r$//' | sudo tee /usr/local/bin/setup_intel_integrated_gpu.sh >/dev/null"
            wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/setup_intel_integrated_gpu.sh
            
            Write-LogMessage "Copied setup_intel_integrated_gpu.sh into WSL: /usr/local/bin/setup_intel_integrated_gpu.sh"
            
            # Execute the script as kamiwaza user
            Write-LogMessage "Executing Intel Integrated Graphics setup as kamiwaza user..."
            wsl -d $WSLDistribution -- sudo -u kamiwaza /usr/local/bin/setup_intel_integrated_gpu.sh
        } catch {
            Write-LogMessage "Failed to set up Intel Integrated Graphics: $($_.Exception.Message)" "ERROR"
        }
    }
    
    # CRITICAL FIX: If no supported GPU detected but we're in a remote/VM environment,
    # we should NOT create NVIDIA scripts as they won't work
    if (-not $nvidiaRTX -and -not $intelArc -and -not $intelIntegrated) {
        Write-LogMessage "No supported GPU acceleration hardware detected" "WARN"
        Write-LogMessage "Kamiwaza will run with CPU-only acceleration"
        
        # Create generic GPU info script
        $genericScript = @"
#!/bin/bash
# Generic GPU Information for Kamiwaza
echo "=== GPU Detection Results ==="
echo "No NVIDIA GeForce RTX or Intel Arc/Integrated GPUs detected"
echo "Available graphics hardware:"
lspci | grep -i vga || echo "No VGA devices found"
lspci | grep -i display || echo "No display devices found"
echo "Kamiwaza will run with CPU-only acceleration"
echo "=== GPU Detection Complete ==="
"@
        
        try {
            $genericScript | wsl -d $WSLDistribution -- sudo tee /usr/local/bin/gpu_info.sh
            wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/gpu_info.sh
            Write-LogMessage "Created generic GPU info script: /usr/local/bin/gpu_info.sh"
        } catch {
            Write-LogMessage "Failed to create generic GPU script: $($_.Exception.Message)" "ERROR"
        }
    }
    
    # Create master GPU status script with enhanced detection
    $statusScript = @"
#!/bin/bash
# Master GPU Status Script for Kamiwaza
echo "=== Kamiwaza GPU Status ==="
echo "Generated: $(date)"
echo ""

# Check what GPU setup scripts actually exist
if [ -f /usr/local/bin/setup_nvidia_gpu.sh ]; then
    echo "NVIDIA GeForce RTX acceleration: CONFIGURED"
    echo "Run: sudo -u kamiwaza /usr/local/bin/setup_nvidia_gpu.sh"
elif [ -f /usr/local/bin/setup_intel_arc_gpu.sh ]; then
    echo "Intel Arc GPU acceleration: CONFIGURED" 
    echo "Run: sudo -u kamiwaza /usr/local/bin/setup_intel_arc_gpu.sh"
elif [ -f /usr/local/bin/setup_intel_integrated_gpu.sh ]; then
    echo "Intel Integrated Graphics acceleration: CONFIGURED"
    echo "Run: sudo -u kamiwaza /usr/local/bin/setup_intel_integrated_gpu.sh"
else
    echo "GPU acceleration: CPU-ONLY MODE"
    echo "Run: /usr/local/bin/gpu_info.sh (if available)"
fi

echo ""
echo "=== Actual Hardware Detection ==="
echo "Checking what GPU hardware is actually available in WSL:"
echo ""

# Check for NVIDIA hardware
if command -v nvidia-smi >/dev/null 2>&1; then
    echo "NVIDIA drivers available:"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || echo "  nvidia-smi failed"
else
    echo "NVIDIA drivers: NOT AVAILABLE"
fi

# Check for Intel OpenCL
if command -v clinfo >/dev/null 2>&1; then
    echo ""
    echo "OpenCL platforms available:"
    clinfo --list 2>/dev/null | grep -E "(Platform|Device)" || echo "  clinfo failed"
else
    echo "OpenCL info: clinfo not available"
fi

# Check for VA-API (Intel graphics)
if command -v vainfo >/dev/null 2>&1; then
    echo ""
    echo "VA-API drivers:"
    vainfo 2>/dev/null | head -5 || echo "  vainfo failed"
else
    echo "VA-API info: vainfo not available"
fi

echo ""
echo "=== End GPU Status ==="
"@
    
    try {
        $statusScript | wsl -d $WSLDistribution -- sudo tee /usr/local/bin/kamiwaza_gpu_status.sh
        wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/kamiwaza_gpu_status.sh
        
        # Fix line endings (remove CRLF) - use dos2unix
        wsl -d $WSLDistribution -- sudo dos2unix /usr/local/bin/kamiwaza_gpu_status.sh
        
        Write-LogMessage "Created master GPU status script: /usr/local/bin/kamiwaza_gpu_status.sh"
    } catch {
        Write-LogMessage "Failed to create GPU status script: $($_.Exception.Message)" "ERROR"
    }
    
    # Configure Windows autostart if GPU was detected
    if ($nvidiaRTX -or $intelArc -or $intelIntegrated) {
        try {
            $flagDir = Join-Path $env:LOCALAPPDATA 'Kamiwaza'
            New-Item -ItemType Directory -Path $flagDir -Force | Out-Null
            $flagFile = Join-Path $flagDir 'restart_required.flag'
            Set-Content -Path $flagFile -Value "GPU setup completed - Kamiwaza should start automatically after restart"
            Write-LogMessage "Created restart flag at $flagFile"

            # Use RunOnce registry entry instead of Task Scheduler (no admin rights required)
            $scriptPath = Join-Path $PSScriptRoot 'kamiwaza_autostart.bat'
            if (Test-Path $scriptPath) {
                $runOnceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
                $runOnceName = "KamiwazaGPUAutostart"
                $runOnceValue = "`"$scriptPath`""
                
                try {
                    Set-ItemProperty -Path $runOnceKey -Name $runOnceName -Value $runOnceValue -Type String -Force
                    Write-LogMessage "Registered RunOnce entry for Kamiwaza autostart (no admin rights required)"
                } catch {
                    Write-LogMessage "Failed to create RunOnce entry: $($_.Exception.Message)" 'WARN'
                    # Fallback: just create the flag file
                    Write-LogMessage "Continuing with restart flag only - user can start manually after restart"
                }
            } else {
                Write-LogMessage "Autostart script not found at $scriptPath" 'WARN'
                Write-LogMessage "You will need to start Kamiwaza manually after restart"
            }
        } catch {
            Write-LogMessage "Failed to configure Windows autostart: $($_.Exception.Message)" 'WARN'
        }
    }
    
} catch {
    Write-LogMessage "Error during GPU detection: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-LogMessage "GPU detection and configuration completed successfully!"
Write-LogMessage "Check GPU status in WSL with: wsl -d $WSLDistribution -- /usr/local/bin/kamiwaza_gpu_status.sh"
Write-LogMessage "Script completed successfully - no user input required"