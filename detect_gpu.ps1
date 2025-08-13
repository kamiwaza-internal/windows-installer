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
set -ex
# NVIDIA GPU Setup Script for WSL2 Ubuntu 24.04
# Designed for NVIDIA GeForce RTX GPUs

echo "=== NVIDIA GeForce RTX GPU Configuration ==="
echo "Setting up NVIDIA GPU acceleration for Kamiwaza..."
echo "Timestamp: `$(date)`"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "`${GREEN}`[INFO]`${NC} `$1"
}

warn() {
    echo -e "`${YELLOW}`[WARN]`${NC} `$1"
}

error() {
    echo -e "`${RED}`[ERROR]`${NC} `$1"
}

header() {
    echo -e "`${BLUE}=== `$1 ===`${NC}"
}

# Check if running in WSL2
check_wsl2() {
    if ! grep -qi microsoft /proc/version; then
        error "This script is designed for WSL2. Please run on WSL2."
        exit 1
    fi
    log "WSL2 environment detected [OK]"
}

# Check Ubuntu version
check_ubuntu_version() {
    if ! lsb_release -d | grep -q "Ubuntu 24.04"; then
        warn "This script is optimized for Ubuntu 24.04. Your version: `$(lsb_release -d | cut -f2)`"
        warn "Continuing with installation..."
    else
        log "Ubuntu 24.04 detected [OK]"
    fi
}

# Prerequisites check
check_prerequisites() {
    header "Checking Prerequisites"
    check_wsl2
    check_ubuntu_version
    
    log "Prerequisites verified. Ensure you have:"
    log "1. Latest Windows 11 and WSL2"
    log "2. Updated NVIDIA GPU drivers from NVIDIA's official site"
    log "3. NVIDIA GeForce RTX GPU"
    echo
}

# Update and upgrade system packages
update_system() {
    header "Updating System Packages"
    log "Updating and upgrading system packages..."
    
    sudo apt update
    export DEBIAN_FRONTEND=noninteractive
    sudo apt upgrade -y
    
    log "System update completed [OK]"
}

# Install Python 3.10 and necessary libraries
install_python_deps() {
    header "Installing Python Dependencies"
    log "Installing Python 3.12 and development libraries..."
    
    sudo apt install -y python3.12 python3.12-dev libpython3.12-dev python3.12-venv golang-cfssl python-is-python3 etcd-client net-tools jq
    
    log "Python dependencies installed [OK]"
}

# Install Docker and Docker Compose
install_docker() {
    header "Installing Docker and Docker Compose"
    log "Installing Docker and related tools..."
    
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    if [ ! -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    fi
    echo "deb [arch=`$(dpkg --print-architecture)` signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu `$(lsb_release -cs)` stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-`$(uname -s)`-`$(uname -m)`" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    log "Docker and Docker Compose installed [OK]"
}

# Install CockroachDB and other dependencies
install_cockroachdb() {
    header "Installing CockroachDB and Dependencies"
    log "Installing CockroachDB and additional libraries..."
    
    wget -qO- https://binaries.cockroachdb.com/cockroach-v23.1.17.linux-amd64.tgz | tar xvz
    sudo cp cockroach-v23.1.17.linux-amd64/cockroach /usr/local/bin
    sudo apt install -y libcairo2-dev libgirepository1.0-dev
    sudo apt update
    
    log "CockroachDB and dependencies installed [OK]"
}

# Install NVIDIA drivers
install_nvidia_drivers() {
    header "Installing NVIDIA Drivers"
    log "Installing NVIDIA GPU drivers and utilities..."
    
    # Add the NVIDIA graphics-drivers PPA for latest drivers
    sudo add-apt-repository -y ppa:graphics-drivers/ppa
    sudo apt update
    
    # First, check if ubuntu-drivers utility is available, install if not
    if ! command -v ubuntu-drivers &> /dev/null; then
        log "Installing ubuntu-drivers-common..."
        sudo apt install -y ubuntu-drivers-common
    fi
    
    # Install specific NVIDIA utilities package
    log "Installing nvidia-utils-575..."
    sudo apt install -y nvidia-utils-575
    
    log "NVIDIA drivers and utilities installed [OK]"
}

# Install PyTorch with CUDA support
install_pytorch() {
    header "Installing PyTorch with CUDA Support"
    log "Installing PyTorch with CUDA 12.8 support..."
    
    # Activate Kamiwaza virtual environment
    if [ -f "/opt/kamiwaza/kamiwaza/venv/bin/activate" ]; then
        log "Activating Kamiwaza virtual environment..."
        source /opt/kamiwaza/kamiwaza/venv/bin/activate
        
        # Install PyTorch with CUDA support
        log "Installing PyTorch with CUDA 12.8..."
        pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
        
        log "PyTorch with CUDA support installed [OK]"
    else
        warn "Kamiwaza virtual environment not found at /opt/kamiwaza/kamiwaza/venv/"
        warn "PyTorch installation skipped - please ensure Kamiwaza is installed first"
    fi
}

# Verify NVIDIA installation
verify_nvidia() {
    header "Verifying NVIDIA Installation"
    log "Checking NVIDIA driver installation..."
    
    if command -v nvidia-smi >/dev/null 2>&1; then
        log "NVIDIA GPU detected:"
        nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null || echo "GPU name detection failed"
        log "NVIDIA Driver version:"
        nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null || echo "Driver version detection failed"
        log "[OK] NVIDIA drivers installed successfully!"
    else
        warn "nvidia-smi not found. Driver installation may have failed."
        warn "This is normal if running in WSL2 without GPU passthrough."
    fi
}

# Final instructions
final_instructions() {
    header "Installation Complete!"
    echo
    log "NVIDIA GPU support has been set up successfully!"
    echo
    warn "IMPORTANT: GPU acceleration may require a FULL SYSTEM REBOOT!"
    echo
    log "Next Steps:"
    echo "  1. Verify NVIDIA drivers: 'nvidia-smi'"
    echo "  2. Test PyTorch CUDA: 'python -c \"import torch; print(torch.cuda.is_available())\"'"
    echo "  3. If GPU not detected, ensure WSL2 GPU passthrough is enabled"
    echo
    log "Troubleshooting:"
    echo "  - Check WSL2 GPU support: 'nvidia-smi'"
    echo "  - Verify PyTorch CUDA: 'python -c \"import torch; print(torch.cuda.device_count())\"'"
    echo "  - Ensure Windows NVIDIA drivers are up to date"
    echo
}

# Main execution
main() {
    header "NVIDIA GPU Setup for WSL2"
    log "Setting up NVIDIA GeForce RTX GPU support on WSL2 Ubuntu 24.04"
    echo
    
    check_prerequisites
    update_system
    install_python_deps
    install_docker
    install_cockroachdb
    install_nvidia_drivers
    install_pytorch
    verify_nvidia
    final_instructions
    
    echo
    log "Setup completed successfully! [SUCCESS]"
}

# Run main function
main "`$@"
"@
        
        try {
            $nvidiaScript | wsl -d $WSLDistribution -- sudo tee /usr/local/bin/setup_nvidia_gpu.sh > $null
            wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/setup_nvidia_gpu.sh
            
            # Fix line endings (remove CRLF) - use dos2unix
            wsl -d $WSLDistribution -- sudo dos2unix /usr/local/bin/setup_nvidia_gpu.sh
            
            Write-LogMessage "Created NVIDIA GPU setup script in WSL: /usr/local/bin/setup_nvidia_gpu.sh"
            
            # Execute the script as kamiwaza user
            Write-LogMessage "Executing NVIDIA GPU setup as kamiwaza user..."
            wsl -d $WSLDistribution -- sudo -u kamiwaza /usr/local/bin/setup_nvidia_gpu.sh
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

# Intel GPU OpenCL Support Setup for WSL2 Ubuntu 24.04
# Designed for Intel Arc 140V GPU and similar Intel GPUs

set -e  # Exit on any error

echo "=== Intel Arc GPU Configuration ==="
echo "Setting up Intel Arc GPU acceleration for Kamiwaza..."
echo "Timestamp: `$(date)`"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "`${GREEN}`[INFO]`${NC} `$1"
}

warn() {
    echo -e "`${YELLOW}`[WARN]`${NC} `$1"
}

error() {
    echo -e "`${RED}`[ERROR]`${NC} `$1"
}

header() {
    echo -e "`${BLUE}=== `$1 ===`${NC}"
}

# Check if running in WSL2
check_wsl2() {
    if ! grep -qi microsoft /proc/version; then
        error "This script is designed for WSL2. Please run on WSL2."
        exit 1
    fi
    
    # Check kernel version
    kernel_version=`$(uname -r | cut -d. -f1,2)`
    if [[ `$(echo "`$kernel_version >= 5.15" | bc -l)` -eq 0 ]]; then
        warn "WSL2 kernel version is `$kernel_version. Recommended: 5.15+. Consider updating WSL2."
    else
        log "WSL2 kernel version: `$kernel_version [OK]"
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    if ! lsb_release -d | grep -q "Ubuntu 24.04"; then
        warn "This script is optimized for Ubuntu 24.04. Your version: `$(lsb_release -d | cut -f2)`"
        warn "Continuing with installation..."
    else
        log "Ubuntu 24.04 detected [OK]"
    fi
}

# Prerequisites check
check_prerequisites() {
    header "Checking Prerequisites"
    check_wsl2
    check_ubuntu_version
    
    log "Prerequisites verified. Ensure you have:"
    log "1. Latest Windows 11 and WSL2"
    log "2. Updated Intel GPU drivers from Intel's official site"
    log "3. Intel Arc 140V GPU or compatible Intel GPU"
    echo
}

# Update system
update_system() {
    header "Updating System"
    log "Updating package lists and upgrading system..."
    sudo apt update && sudo apt upgrade -y
    log "System update completed [OK]"
}

# Remove conflicting packages
remove_conflicts() {
    header "Removing Conflicting Packages"
    log "Removing potentially conflicting Intel OpenCL packages..."
    sudo apt-get purge -y intel-opencl-icd intel-level-zero-gpu level-zero 2>/dev/null || true
    sudo apt-get autoremove -y
    sudo apt-get clean
    log "Conflicting packages removed [OK]"
}

# Install OpenCL loader and tools
install_opencl_tools() {
    header "Installing OpenCL Loader and Tools"
    log "Installing OpenCL development tools..."
    sudo apt-get update
    sudo apt-get install -y ocl-icd-libopencl1 ocl-icd-opencl-dev opencl-headers clinfo bc
    log "OpenCL tools installed [OK]"
}

# Add Intel oneAPI repository and install runtime
install_intel_opencl() {
    header "Installing Intel OpenCL Runtime"
    log "Adding Intel oneAPI repository..."
    
    # Add Intel oneAPI repository key
    if [ ! -f /usr/share/keyrings/oneapi-archive-keyring.gpg ]; then
        wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
    fi
    
    # Add the repository
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
    
    # Update and install the OpenCL runtime
    sudo apt-get update
    sudo apt-get install -y intel-oneapi-runtime-opencl
    
    log "Intel OpenCL runtime installed [OK]"
}

# Install Intel Graphics PPA (optional but recommended)
install_intel_graphics_ppa() {
    header "Installing Intel Graphics Drivers (Recommended)"
    log "Installing latest hardware acceleration and media support..."
    
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:kobuk-team/intel-graphics
    sudo apt-get update
    sudo apt-get install -y intel-media-va-driver-non-free libmfx-gen1 libvpl2 libvpl-tools libva-glx2 va-driver-all vainfo
    
    log "Intel Graphics drivers installed [OK]"
}

# Configure permissions
configure_permissions() {
    header "Configuring Permissions"
    log "Adding user to render group..."
    sudo usermod -a -G render `$USER
    
    # Check if /dev/dri exists
    if [ -d "/dev/dri" ]; then
        log "GPU devices found:"
        ls -la /dev/dri/ | grep -E "(card|render)" || warn "No GPU devices found in /dev/dri"
    else
        warn "/dev/dri directory not found. This may be normal in WSL2."
    fi
    
    log "Permissions configured [OK]"
    warn "Note: You may need to restart your WSL2 session for group changes to take effect."
}

# Verify OpenCL installation
verify_opencl() {
    header "Verifying OpenCL Installation"
    log "Running clinfo to check OpenCL devices..."
    log "Note: GPU may show as CPU until after full system reboot"
    echo
    
    if command -v clinfo >/dev/null 2>&1; then
        clinfo_output=`$(clinfo 2>&1)`
        echo "`$clinfo_output"
        
        if echo "`$clinfo_output" | grep -qi "intel"; then
            if echo "`$clinfo_output" | grep -q "Device Type.*GPU"; then
                log "[OK] Intel GPU OpenCL platform detected!"
            elif echo "`$clinfo_output" | grep -q "Device Type.*CPU"; then
                warn "Intel OpenCL detected but showing as CPU device"
                warn "This is normal before system reboot - GPU will appear after reboot"
            else
                log "[OK] Intel OpenCL platform detected"
            fi
        elif echo "`$clinfo_output" | grep -qi "microsoft"; then
            log "[OK] Microsoft Basic Render Driver detected (normal in WSL2)"
        else
            warn "No Intel OpenCL devices found yet. Full system reboot may be required."
        fi
    else
        error "clinfo command not found. Installation may have failed."
        return 1
    fi
}

# Install build dependencies for development
install_build_deps() {
    header "Installing Build Dependencies"
    log "Installing dependencies for OpenCL development..."
    sudo apt-get install -y build-essential cmake libcurl4-openssl-dev git
    log "Build dependencies installed [OK]"
}

# Install monitoring tools
install_monitoring() {
    header "Installing GPU Monitoring Tools"
    log "Installing intel-gpu-tools for GPU monitoring..."
    
    sudo apt-get install -y intel-gpu-tools
    log "Monitoring tools installed [OK]"
    log "Note: Use 'sudo intel_gpu_top' to monitor GPU usage"
    warn "Note: In WSL2, monitoring may not work as expected due to GPU virtualization"
}

# Final instructions
final_instructions() {
    header "Installation Complete!"
    echo
    log "Intel GPU OpenCL support has been set up successfully!"
    echo
    warn "IMPORTANT: GPU acceleration requires a FULL SYSTEM REBOOT!"
    echo
    log "REQUIRED Next Steps:"
    echo "  1. Save your work and close all applications"
    echo "  2. REBOOT your entire Windows system (not just WSL2)"
    echo "  3. After reboot, restart WSL2 and verify: 'clinfo'"
    echo "  4. Look for 'Device Type: GPU' in clinfo output"
    echo
    
    log "Optional monitoring:"
    echo "  - Test GPU monitoring: 'sudo intel_gpu_top' (may not work in WSL2)"
    echo
    
    log "Why full reboot is needed:"
    echo "  - WSL2 GPU virtualization requires Windows driver reinitialization"
    echo "  - Intel Arc discrete GPUs need full system restart for WSL2 recognition"
    echo "  - Simply restarting WSL2 is insufficient for discrete GPU detection"
    echo
    
    log "Troubleshooting after reboot:"
    echo "  - If clinfo still shows CPU only, update Windows Intel GPU drivers"
    echo "  - For issues, provide output of: clinfo && ls -la /dev/dri/"
    echo "  - Ensure WSL2 and Windows are fully updated"
    echo
    warn "Remember: FULL SYSTEM REBOOT is required for Intel Arc 140V GPU to work in WSL2!"
}

# Main execution
main() {
    header "Intel GPU OpenCL Setup for WSL2"
    log "Setting up OpenCL support for Intel Arc 140V GPU on WSL2 Ubuntu 24.04"
    echo
    
    check_prerequisites
    update_system
    remove_conflicts
    install_opencl_tools
    install_intel_opencl
    install_intel_graphics_ppa
    configure_permissions
    verify_opencl
    install_build_deps
    install_monitoring
    final_instructions
    
    echo
    log "Setup completed successfully! [SUCCESS]"
    warn "[REBOOT] REBOOT YOUR ENTIRE WINDOWS SYSTEM NOW to activate GPU support!"
}

# Run main function
main "`$@"
"@
        
        try {
            $intelScript | wsl -d $WSLDistribution -- sudo tee /usr/local/bin/setup_intel_arc_gpu.sh > $null
            wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/setup_intel_arc_gpu.sh
            
            # Fix line endings (remove CRLF) - use dos2unix
            wsl -d $WSLDistribution -- sudo dos2unix /usr/local/bin/setup_intel_arc_gpu.sh
            
            Write-LogMessage "Created Intel Arc GPU setup script in WSL: /usr/local/bin/setup_intel_arc_gpu.sh"
            
            # Execute the script as kamiwaza user
            Write-LogMessage "Executing Intel Arc GPU setup as kamiwaza user..."
            wsl -d $WSLDistribution -- sudo -u kamiwaza /usr/local/bin/setup_intel_arc_gpu.sh
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
    echo "Run: sudo -u kamiwaza /usr/local/bin/setup_nvidia_gpu.sh"
elif [ -f /usr/local/bin/setup_intel_arc_gpu.sh ]; then
    echo "Intel Arc GPU acceleration: CONFIGURED" 
    echo "Run: sudo -u kamiwaza /usr/local/bin/setup_intel_arc_gpu.sh"
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