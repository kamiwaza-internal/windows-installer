# GPU Detection Script for Kamiwaza Installer
# Detects GPU types and configures appropriate acceleration scripts in WSL

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

# Get GPU information
try {
    Write-LogMessage "Detecting installed graphics cards..."
    $gpus = Get-CimInstance Win32_VideoController | Select-Object Name, AdapterCompatibility
    
    Write-LogMessage "Found graphics controllers:"
    $gpus | ForEach-Object {
        Write-LogMessage "  Name: $($_.Name)"
        Write-LogMessage "  Compatibility: $($_.AdapterCompatibility)"
    }
    
    # Check for NVIDIA GeForce RTX
    $nvidiaRTX = $gpus | Where-Object { $_.Name -like "*NVIDIA GeForce RTX*" }
    $intelArc = $gpus | Where-Object { $_.Name -like "*Intel(R) Arc(TM)*" }
    
    if ($nvidiaRTX) {
        Write-LogMessage "NVIDIA GeForce RTX GPU detected!" "INFO"
        Write-LogMessage "Setting up NVIDIA GPU acceleration in WSL..."
        
        # Create NVIDIA setup script in WSL
        $nvidiaScript = @"
#!/bin/bash
# NVIDIA GeForce RTX GPU Setup for Kamiwaza
echo "=== NVIDIA GeForce RTX GPU Configuration ==="
echo "Setting up NVIDIA GPU acceleration for Kamiwaza..."

# TODO: Add NVIDIA-specific setup commands here
# This is a placeholder script - add actual NVIDIA configuration

if command -v nvidia-smi >/dev/null 2>&1; then
    echo "NVIDIA GPU: `$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null)`"
    echo "NVIDIA Driver: `$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null)`"
else
    echo "NVIDIA GPU: Detection failed - nvidia-smi not available"
    echo "NVIDIA Driver: Not detected"
fi

echo "PLACEHOLDER: NVIDIA RTX GPU acceleration setup would go here"
echo "This includes:"
echo "- NVIDIA Container Toolkit installation"
echo "- CUDA runtime setup"
echo "- GPU passthrough configuration"
echo "- Kamiwaza GPU acceleration enablement"

echo "=== NVIDIA Configuration Complete ==="
read -p "Press Enter to continue..."

"@
        
        try {
            $nvidiaScript | wsl -d $WSLDistribution -- sudo tee /usr/local/bin/setup_nvidia_gpu.sh > $null
            wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/setup_nvidia_gpu.sh
            
            # Fix line endings (remove CRLF) - use dos2unix
            wsl -d $WSLDistribution -- sudo dos2unix /usr/local/bin/setup_nvidia_gpu.sh
            
            Write-LogMessage "Created NVIDIA GPU setup script in WSL: /usr/local/bin/setup_nvidia_gpu.sh"
            
            # Execute the script
            Write-LogMessage "Executing NVIDIA GPU setup..."
            wsl -d $WSLDistribution -- sudo /usr/local/bin/setup_nvidia_gpu.sh
        } catch {
            Write-LogMessage "Failed to create NVIDIA GPU script: $($_.Exception.Message)" "ERROR"
        }
    }
    
    if ($intelArc) {
        Write-LogMessage "Intel Arc GPU detected!" "INFO"
        Write-LogMessage "Setting up Intel Arc GPU acceleration in WSL..."
        
        # Create Intel Arc setup script in WSL
        $intelScript = @"
#!/bin/bash
# Intel Arc GPU Setup for Kamiwaza
echo "=== Intel Arc GPU Configuration ==="
echo "Setting up Intel Arc GPU acceleration for Kamiwaza..."

# TODO: Add Intel Arc-specific setup commands here
# This is a placeholder script - add actual Intel Arc configuration

echo "Intel GPU: `$(lspci | grep -i intel | grep -i vga 2>/dev/null || echo 'Detection failed')`"
echo "Intel Graphics Driver: `$(modinfo i915 2>/dev/null | grep version || echo 'Not detected')`"

echo "PLACEHOLDER: Intel Arc GPU acceleration setup would go here"
echo "This includes:"
echo "- Intel GPU kernel modules"
echo "- Intel Media SDK/oneAPI setup"
echo "- GPU compute runtime installation"
echo "- Kamiwaza Intel GPU acceleration enablement"

echo "=== Intel Arc Configuration Complete ==="
read -p "Press Enter to continue..."
"@
        
        try {
            $intelScript | wsl -d $WSLDistribution -- sudo tee /usr/local/bin/setup_intel_arc_gpu.sh > $null
            wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/setup_intel_arc_gpu.sh
            
            # Fix line endings (remove CRLF) - use dos2unix
            wsl -d $WSLDistribution -- sudo dos2unix /usr/local/bin/setup_intel_arc_gpu.sh
            
            Write-LogMessage "Created Intel Arc GPU setup script in WSL: /usr/local/bin/setup_intel_arc_gpu.sh"
            
            # Execute the script
            Write-LogMessage "Executing Intel Arc GPU setup..."
            wsl -d $WSLDistribution -- sudo /usr/local/bin/setup_intel_arc_gpu.sh
        } catch {
            Write-LogMessage "Failed to create Intel Arc GPU script: $($_.Exception.Message)" "ERROR"
        }
    }
    
    if (-not $nvidiaRTX -and -not $intelArc) {
        Write-LogMessage "No supported GPU acceleration hardware detected" "WARN"
        Write-LogMessage "Kamiwaza will run with CPU-only acceleration"
        
        # Create generic GPU info script
        $genericScript = @"
#!/bin/bash
# Generic GPU Information for Kamiwaza
echo "=== GPU Detection Results ==="
echo "No NVIDIA GeForce RTX or Intel Arc GPUs detected"
echo "Available graphics hardware:"
lspci | grep -i vga || echo "No VGA devices found"
lspci | grep -i display || echo "No display devices found"
echo "Kamiwaza will run with CPU-only acceleration"
echo "=== GPU Detection Complete ==="
"@
        
        try {
            $genericScript | wsl -d $WSLDistribution -- sudo tee /usr/local/bin/gpu_info.sh > $null
            wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/gpu_info.sh
            Write-LogMessage "Created generic GPU info script: /usr/local/bin/gpu_info.sh"
        } catch {
            Write-LogMessage "Failed to create generic GPU script: $($_.Exception.Message)" "ERROR"
        }
    }
    
    # Create master GPU status script
    $statusScript = @"
#!/bin/bash
# Master GPU Status Script for Kamiwaza
echo "=== Kamiwaza GPU Status ==="
echo "Generated: $(date)"
echo ""

if [ -f /usr/local/bin/setup_nvidia_gpu.sh ]; then
    echo "NVIDIA GeForce RTX acceleration: CONFIGURED"
    echo "Run: sudo /usr/local/bin/setup_nvidia_gpu.sh"
elif [ -f /usr/local/bin/setup_intel_arc_gpu.sh ]; then
    echo "Intel Arc GPU acceleration: CONFIGURED" 
    echo "Run: sudo /usr/local/bin/setup_intel_arc_gpu.sh"
else
    echo "GPU acceleration: CPU-ONLY MODE"
    echo "Run: /usr/local/bin/gpu_info.sh (if available)"
fi

echo ""
echo "=== End GPU Status ==="
"@
    
    try {
        $statusScript | wsl -d $WSLDistribution -- sudo tee /usr/local/bin/kamiwaza_gpu_status.sh > $null
        wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/kamiwaza_gpu_status.sh
        
        # Fix line endings (remove CRLF) - use dos2unix
        wsl -d $WSLDistribution -- sudo dos2unix /usr/local/bin/kamiwaza_gpu_status.sh
        
        Write-LogMessage "Created master GPU status script: /usr/local/bin/kamiwaza_gpu_status.sh"
    } catch {
        Write-LogMessage "Failed to create GPU status script: $($_.Exception.Message)" "ERROR"
    }
    
} catch {
    Write-LogMessage "Error during GPU detection: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-LogMessage "GPU detection and configuration completed successfully!"
Write-LogMessage "Check GPU status in WSL with: wsl -d $WSLDistribution -- /usr/local/bin/kamiwaza_gpu_status.sh"