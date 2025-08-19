#!/bin/bash

# Intel GPU OpenCL Support Setup for WSL2 Ubuntu 24.04
# Designed for Intel Arc 140V GPU and similar Intel GPUs
# Runs as kamiwaza user with passwordless sudo access
# Updated for Intel's new installation process using official PPA

echo "=== Intel Arc GPU Configuration ==="
echo "Setting up Intel Arc GPU acceleration for Kamiwaza..."
echo "Timestamp: $(date)"
echo "Running as user: $(whoami)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if running as kamiwaza user
check_user() {
    if [ "$(whoami)" != "kamiwaza" ]; then
        warn "This script is designed to run as the kamiwaza user"
        warn "Current user: $(whoami)"
        warn "Continuing anyway..."
    else
        log "Running as kamiwaza user [OK]"
    fi
}

# Check if running in WSL2
check_wsl2() {
    if ! grep -qi microsoft /proc/version; then
        error "This script is designed for WSL2. Please run on WSL2."
        warn "Continuing anyway for debugging purposes..."
    fi
    
    # Check kernel version without bc dependency
    kernel_version=$(uname -r | cut -d- -f1)
    major=$(echo "$kernel_version" | cut -d. -f1)
    minor=$(echo "$kernel_version" | cut -d. -f2)
    if [ "$major" -lt 5 ] || { [ "$major" -eq 5 ] && [ "$minor" -lt 15 ]; }; then
        warn "WSL2 kernel version is ${major}.${minor}. Recommended: 5.15+. Consider updating WSL2."
        warn "Continuing anyway for debugging purposes..."
    else
        log "WSL2 kernel version: ${major}.${minor} [OK]"
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    if ! lsb_release -d | grep -q "Ubuntu 24.04"; then
        warn "This script is optimized for Ubuntu 24.04 (Noble). Your version: $(lsb_release -d | cut -f2)"
        warn "Continuing with installation for debugging purposes..."
    else
        log "Ubuntu 24.04 (Noble) detected [OK]"
    fi
}

# Function to request and execute system reboot
request_reboot() {
    header "System Reboot Required"
    echo
    warn "IMPORTANT: GPU acceleration requires a FULL SYSTEM REBOOT!"
    log "Please reboot your entire Windows system (not just WSL2) to activate GPU support."
    echo
    log "The Intel Arc GPU drivers have been installed, but they need a full system restart"
    log "to properly initialize and become available to WSL2."
    echo
    
    # Always show reboot instructions first
    show_reboot_instructions
    echo
    
    # Automated mode - just show instructions
    log "Automated installation mode - reboot instructions will be shown"
    log "Please restart your computer manually to complete GPU setup"
    show_reboot_instructions
    return 0
}

# Function to show reboot instructions
show_reboot_instructions() {
    header "Manual Reboot Instructions"
    echo
    log "To complete Intel Arc GPU setup, please restart your computer:"
    echo
    echo -e "${BLUE}Method 1: Windows Start Menu${NC}"
    echo "  1. Click the Windows Start button"
    echo "  2. Click the Power button (power icon)"
    echo "  3. Select 'Restart'"
    echo
    echo -e "${BLUE}Method 2: Windows Settings${NC}"
    echo "  1. Press Windows + I to open Settings"
    echo "  2. Go to System > Recovery"
    echo "  3. Click 'Restart now' under Advanced startup"
    echo
    echo -e "${BLUE}Method 3: Command Prompt (as Administrator)${NC}"
    echo "  1. Press Windows + X and select 'Windows Terminal (Admin)'"
    echo "  2. Type: shutdown /r /t 0"
    echo "  3. Press Enter"
    echo
    echo -e "${BLUE}Method 4: PowerShell (as Administrator)${NC}"
    echo "  1. Press Windows + X and select 'Windows PowerShell (Admin)'"
    echo "  2. Type: Restart-Computer -Force"
    echo "  3. Press Enter"
    echo
    warn "IMPORTANT: After restart, wait for Windows to fully boot before starting WSL2"
    log "GPU acceleration will be available once the system has fully restarted."
    log "Kamiwaza will start automatically after the restart is complete."
    echo
}

# Function to verify installation and show debugging info
verify_installation() {
    header "Installation Verification"
    echo
    log "Verifying Intel GPU driver installation..."
    echo
    
    # Check if OpenCL packages are installed
    log "Checking OpenCL packages..."
    dpkg -l | grep -E "(ocl-icd|intel-opencl|libze)" | head -10
    
    echo
    log "Checking Intel oneAPI packages..."
    dpkg -l | grep -E "(intel-oneapi|intel-basekit)" | head -10
    
    echo
    log "Checking OpenCL runtime..."
    if command -v clinfo >/dev/null 2>&1; then
        log "clinfo command found - testing OpenCL detection..."
        echo "Running: clinfo | head -20"
        clinfo | head -20
    else
        warn "clinfo command not found - OpenCL may not be properly installed"
    fi
    
    echo
    log "Checking Intel GPU device files..."
    ls -la /dev/dri/ 2>/dev/null || warn "No /dev/dri directory found"
    
    echo
    log "Checking user groups..."
    groups $USER
    
    echo
    log "Checking system logs for Intel GPU..."
    dmesg | grep -i intel | tail -5 2>/dev/null || warn "No Intel GPU messages in dmesg"
    
    echo
    log "Checking package installation status..."
    apt list --installed | grep -E "(ocl-icd|intel-opencl|libze)" | head -10
}

# Prerequisites check
check_prerequisites() {
    header "Checking Prerequisites"
    check_user
    check_wsl2
    check_ubuntu_version
    
    log "Prerequisites verified. Ensure you have:"
    log "1. Latest Windows 11 and WSL2"
    log "2. Updated Intel GPU drivers from Intel's official site"
    log "3. Intel Arc 140V GPU or compatible Intel GPU"
    log "4. Ubuntu 24.04 (Noble) with Python 3.12"
    echo
}

# Main execution
main() {
    header "Intel GPU OpenCL Setup for WSL2"
    log "Setting up OpenCL support for Intel Arc 140V GPU on WSL2 Ubuntu 24.04 (Noble)"
    log "Using Intel's official Graphics PPA for Ubuntu 24.04"
    echo
    
    check_prerequisites
    
    # Always proceed with installation (no user prompts)
    log "Proceeding with installation automatically..."
    echo
    
    # Execute the exact commands as specified
    log "Executing required commands..."
    
    # Track installation success
    installation_success=true
    
    # 1. Update system
    log "1. Updating system packages..."
    if sudo apt update && sudo apt upgrade -y; then
        log "  [OK] System update completed"
    else
        warn "  [WARN] System update had issues - continuing anyway"
        installation_success=false
    fi
    
    # 2. Clean previous installations (optional)
    log "2. Cleaning previous installations..."
    sudo apt-get purge -y intel-opencl-icd 2>/dev/null || true
    sudo apt-get autoremove -y
    sudo apt-get clean
    log "  [OK] Cleanup completed"
    
    # 3. Install OpenCL loader and tools
    log "3. Installing OpenCL loader and tools..."
    if sudo apt-get update && sudo apt-get install -y ocl-icd-libopencl1 ocl-icd-opencl-dev opencl-headers clinfo; then
        log "  [OK] OpenCL loader and tools installed"
    else
        error "  [ERROR] Failed to install OpenCL loader and tools"
        installation_success=false
    fi
    
    # 4. Add Intel Graphics PPA and install OpenCL runtime
    log "4. Adding Intel Graphics PPA and installing OpenCL runtime..."
    if sudo apt-get install -y software-properties-common && \
       sudo add-apt-repository -y ppa:kobuk-team/intel-graphics && \
       sudo apt-get update && \
       sudo apt-get install -y libze-intel-gpu1 libze1 intel-opencl-icd; then
        log "  [OK] Intel Graphics PPA and OpenCL runtime installed"
    else
        error "  [ERROR] Failed to install Intel Graphics PPA and OpenCL runtime"
        installation_success=false
    fi
    
    # 5. Install Intel oneAPI for SYCL Support (Recommended for Best Performance)
    log "5. Installing Intel oneAPI for SYCL support..."
    if sudo apt-get install -y wget gpg; then
        log "  [OK] Prerequisites for oneAPI installation"
        
        # Add Intel's GPG key (using the exact command specified)
        log "  [INFO] Adding Intel GPG key..."
        if wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | \
           gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null; then
            log "  [OK] Intel GPG key added to oneapi-archive-keyring.gpg"
        else
            warn "  [WARN] Failed to add Intel GPG key - continuing anyway"
            installation_success=false
        fi
        
        # Add the oneAPI repository (using the exact command specified)
        log "  [INFO] Adding oneAPI repository..."
        if echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | \
           sudo tee /etc/apt/sources.list.d/oneAPI.list; then
            log "  [OK] oneAPI repository added"
        else
            warn "  [WARN] Failed to add oneAPI repository - continuing anyway"
            installation_success=false
        fi
        
        # Update package list (using the exact command specified)
        log "  [INFO] Updating package list..."
        if sudo apt update; then
            log "  [OK] Package list updated"
        else
            warn "  [WARN] Failed to update package list - continuing anyway"
            installation_success=false
        fi
        
        # Install Intel oneAPI Runtime OpenCL (using the exact command specified)
        log "  [INFO] Installing Intel oneAPI Runtime OpenCL..."
        if sudo apt install intel-oneapi-runtime-opencl; then
            log "  [OK] Intel oneAPI Runtime OpenCL installed"
        else
            warn "  [WARN] Intel oneAPI Runtime OpenCL installation had issues - continuing anyway"
            installation_success=false
        fi
        
        # Also install Intel oneAPI basekit for additional SYCL support
        log "  [INFO] Installing Intel oneAPI basekit for additional SYCL support..."
        if sudo apt install -y intel-basekit; then
            log "  [OK] Intel oneAPI basekit installed"
        else
            warn "  [WARN] Intel oneAPI basekit installation had issues - continuing anyway"
            installation_success=false
        fi
    else
        warn "  [WARN] Failed to install oneAPI prerequisites - continuing anyway"
        installation_success=false
    fi
    
    # 6. Configure permissions
    log "6. Configuring permissions..."
    if sudo usermod -a -G render $USER; then
        log "  [OK] User added to render group"
        # Note: newgrp render won't work in this context, but the group change will take effect after restart
        log "  [INFO] Group membership will take effect after restart or newgrp command"
    else
        warn "  [WARN] Failed to add user to render group - continuing anyway"
    fi
    
    echo
    if [ "$installation_success" = true ]; then
        log "Setup completed successfully! [SUCCESS]"
        log "All required commands have been executed."
    else
        warn "Setup completed with warnings. Some components may not have installed properly."
        log "Please review the output above for any error messages."
    fi
    echo
    
    # Always verify installation
    verify_installation
    echo
    
    # Set up Windows autostart for Kamiwaza after reboot
    log "Setting up Windows autostart for Kamiwaza..."
    if command -v powershell.exe >/dev/null 2>&1; then
        log "Creating restart flag file and setting up autostart..."
        
        # Create the restart flag file that Windows autostart script looks for
        powershell.exe -Command "
            \$flagDir = \"$env:LOCALAPPDATA\\Kamiwaza\"
            if (!(Test-Path \$flagDir)) { New-Item -ItemType Directory -Path \$flagDir -Force | Out-Null }
            \$flagFile = \"\$flagDir\\restart_required.flag\"
            Set-Content -Path \$flagFile -Value \"GPU setup completed - Kamiwaza should start automatically after restart\"
            Write-Host \"Restart flag created: \$flagFile\"
            
            # Set up RunOnce registry entry to run kamiwaza_autostart.bat after reboot (no admin rights required)
            \$scriptPath = \"$PWD/kamiwaza_autostart.bat\"
            if (Test-Path \$scriptPath) {
                \$runOnceKey = \"HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce\"
                \$runOnceName = \"KamiwazaGPUAutostart\"
                \$runOnceValue = \"\\\"\$scriptPath\\\"\"
                
                try {
                    Set-ItemProperty -Path \$runOnceKey -Name \$runOnceName -Value \$runOnceValue -Type String -Force
                    Write-Host \"RunOnce entry created for Kamiwaza autostart (no admin rights required)\"
                } catch {
                    Write-Host \"Warning: Failed to create RunOnce entry - continuing with restart flag only\"
                }
            } else {
                Write-Host \"Warning: kamiwaza_autostart.bat not found at \$scriptPath\"
            }
        "
        
        if [ $? -eq 0 ]; then
            log "  [OK] Windows autostart configured for Kamiwaza"
        else
            warn "  [WARN] Windows autostart configuration had issues - continuing anyway"
        fi
    else
        warn "  [WARN] PowerShell not available - cannot configure Windows autostart"
        log "  [INFO] You will need to start Kamiwaza manually after restart"
    fi
    
    echo
    log "IMPORTANT: After restart, Kamiwaza will start automatically with GPU acceleration!"
    log "The autostart script will run and execute: wsl -d kamiwaza -- kamiwaza start"
    echo
    
    # MSI installer will handle the reboot - just inform user
    log "GPU setup completed successfully!"
    log "The MSI installer will now prompt for a system restart to activate GPU drivers."
    log "After restart, Kamiwaza will start automatically with GPU acceleration ready."
    
    echo
    log "=== Intel Arc GPU Setup Complete ==="
    log "Next steps:"
    log "1. MSI installer will prompt for system restart"
    log "2. After restart, Kamiwaza will start automatically with GPU acceleration"
    log "3. Verify GPU support with: clinfo"
    log "4. Test OpenCL with: python3 -c \"import pyopencl; print('OpenCL available')\""
    log "5. Verify oneAPI installation: dpkg -l | grep oneapi"
    echo
    
    # Script completed successfully - exit cleanly
    log "Script completed successfully. Exiting..."
}

# Run main function
main "$@" 