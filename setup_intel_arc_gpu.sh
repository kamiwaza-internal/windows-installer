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
        read -p "Press Enter to continue anyway..."
    fi
    
    # Check kernel version
    kernel_version=$(uname -r | cut -d. -f1,2)
    if [[ $(echo "$kernel_version >= 5.15" | bc -l) -eq 0 ]]; then
        warn "WSL2 kernel version is $kernel_version. Recommended: 5.15+. Consider updating WSL2."
        read -p "Press Enter to continue..."
    else
        log "WSL2 kernel version: $kernel_version [OK]"
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    if ! lsb_release -d | grep -q "Ubuntu 24.04"; then
        warn "This script is optimized for Ubuntu 24.04 (Noble). Your version: $(lsb_release -d | cut -f2)"
        warn "Continuing with installation..."
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
    
    # Check if we're in an interactive terminal
    if [ -t 0 ]; then
        echo -e "${YELLOW}Would you like to reboot your computer now?${NC}"
        echo -e "${YELLOW}This will restart your ENTIRE Windows system, not just WSL2.${NC}"
        echo
        echo -e "${BLUE}Options:${NC}"
        echo -e "  ${GREEN}y${NC} - Yes, reboot now (recommended)"
        echo -e "  ${GREEN}n${NC} - No, I'll reboot manually later"
        echo -e "  ${GREEN}s${NC} - Show reboot instructions"
        echo
        
        while true; do
            read -p "Enter your choice (y/n/s): " choice
            case $choice in
                [Yy]* )
                    log "User chose to reboot now. Preparing system restart..."
                    echo
                    warn "WARNING: Your computer will restart in 10 seconds!"
                    warn "Save any unsaved work immediately!"
                    echo
                    
                    # Countdown for user safety
                    for i in {10..1}; do
                        echo -e "${RED}Restarting in $i seconds... (Press Ctrl+C to cancel)${NC}"
                        sleep 1
                    done
                    
                    echo
                    log "Executing system restart..."
                    
                    # Try multiple methods to reboot the Windows system
                    # Method 1: Use WSL's Windows integration with PowerShell
                    if command -v powershell.exe >/dev/null 2>&1; then
                        log "Using PowerShell to restart Windows..."
                        powershell.exe -Command "Restart-Computer -Force"
                    # Method 2: Use Windows shutdown command through WSL
                    elif command -v cmd.exe >/dev/null 2>&1; then
                        log "Using Windows shutdown command..."
                        cmd.exe /c "shutdown /r /t 0"
                    # Method 3: Use WSL's Windows integration with shutdown
                    else
                        log "Using WSL Windows integration..."
                        /mnt/c/Windows/System32/shutdown.exe /r /t 0
                    fi
                    
                    # If we get here, the reboot command failed
                    error "Failed to execute system restart command"
                    log "Please restart your computer manually to complete GPU setup"
                    return 1
                    ;;
                [Nn]* )
                    log "Reboot skipped. You can restart manually later."
                    log "Remember: GPU acceleration will not work until you restart your computer."
                    return 0
                    ;;
                [Ss]* )
                    show_reboot_instructions
                    return 0
                    ;;
                * )
                    echo "Please enter y, n, or s."
                    ;;
            esac
        done
    else
        # Non-interactive mode
        warn "Non-interactive mode detected - cannot prompt for reboot"
        log "Please restart your computer manually to complete GPU setup"
        show_reboot_instructions
        return 0
    fi
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
    echo
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
    
    # Execute the exact commands as specified
    log "Executing required commands..."
    
    # 1. Update system
    log "1. Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    
    # 2. Clean previous installations (optional)
    log "2. Cleaning previous installations..."
    sudo apt-get purge -y intel-opencl-icd 2>/dev/null || true
    sudo apt-get autoremove -y
    sudo apt-get clean
    
    # 3. Install OpenCL loader and tools
    log "3. Installing OpenCL loader and tools..."
    sudo apt-get update
    sudo apt-get install -y ocl-icd-libopencl1 ocl-icd-opencl-dev opencl-headers clinfo
    
    # 4. Add Intel Graphics PPA and install OpenCL runtime
    log "4. Adding Intel Graphics PPA and installing OpenCL runtime..."
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository -y ppa:kobuk-team/intel-graphics
    sudo apt-get update
    sudo apt-get install -y libze-intel-gpu1 libze1 intel-opencl-icd
    
    # 5. Configure permissions
    log "5. Configuring permissions..."
    sudo usermod -a -G render $USER
    newgrp render
    
    echo
    log "Setup completed successfully! [SUCCESS]"
    log "All required commands have been executed."
    echo
    
    # Request system reboot
    request_reboot
    
    echo
    log "=== Intel Arc GPU Setup Complete ==="
    log "Next steps:"
    log "1. Restart your computer (if not done automatically)"
    log "2. After restart, verify GPU support with: clinfo"
    log "3. Test OpenCL with: python3 -c \"import pyopencl; print('OpenCL available')\""
    echo
}

# Run main function
main "$@" 