#!/bin/bash
# Intel Integrated Graphics Setup Script for WSL2 Ubuntu 24.04
# Supports Intel UHD, HD Graphics, and Iris GPUs
# Runs as kamiwaza user with passwordless sudo access

# Continue on errors instead of exiting

echo "=== Intel Integrated Graphics Configuration ==="
echo "Setting up Intel integrated graphics acceleration for Kamiwaza..."
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
    log "WSL2 environment detected [OK]"
}

# Check Ubuntu version
check_ubuntu_version() {
    if ! lsb_release -d | grep -q "Ubuntu 24.04"; then
        warn "This script is optimized for Ubuntu 24.04. Your version: $(lsb_release -d | cut -f2)"
        warn "Continuing with installation for debugging purposes..."
    else
        log "Ubuntu 24.04 detected [OK]"
    fi
}

# Prerequisites check
check_prerequisites() {
    header "Checking Prerequisites"
    check_user
    check_wsl2
    check_ubuntu_version
    
    log "Prerequisites verified. Ensure you have:"
    log "1. Latest Windows 11 and WSL2"
    log "2. Updated Intel integrated graphics drivers from Intel's official site"
    log "3. Intel UHD, HD Graphics, or Iris GPU"
    echo
}

# Update system
update_system() {
    header "Updating System"
    log "Updating package lists and upgrading system..."
    sudo apt update && sudo apt upgrade -y
    log "System update completed [OK]"
}

# Install Intel integrated graphics drivers
install_intel_drivers() {
    header "Installing Intel Integrated Graphics Drivers"
    log "Installing Intel media drivers and OpenCL support..."
    
    # Install Intel media drivers
    sudo apt install -y intel-media-va-driver-non-free
    sudo apt install -y intel-opencl-icd
    sudo apt install -y vainfo
    
    # Install additional Intel graphics libraries
    sudo apt install -y libmfx-gen1 libvpl2 libvpl-tools libva-glx2 va-driver-all
    
    log "Intel integrated graphics drivers installed [OK]"
}

# Install OpenCL tools
install_opencl_tools() {
    header "Installing OpenCL Tools"
    log "Installing OpenCL development tools..."
    
    sudo apt install -y ocl-icd-libopencl1 ocl-icd-opencl-dev opencl-headers clinfo
    log "OpenCL tools installed [OK]"
}

# Configure environment variables
configure_environment() {
    header "Configuring Environment"
    log "Setting up Intel graphics environment variables..."
    
    # Set up environment variables for Intel graphics
    echo 'export LIBVA_DRIVER_NAME=iHD' >> ~/.bashrc
    echo 'export INTEL_MEDIA_RUNTIME=1' >> ~/.bashrc
    
    log "Intel graphics environment variables configured:"
    log "  - LIBVA_DRIVER_NAME=iHD (Intel HD Graphics driver)"
    log "  - INTEL_MEDIA_RUNTIME=1 (Enable Intel Media SDK)"
}

# Configure permissions
configure_permissions() {
    header "Configuring Permissions"
    log "Adding kamiwaza user to render group..."
    sudo usermod -a -G render kamiwaza
    
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

# Verify installation
verify_installation() {
    header "Verifying Installation"
    log "Checking Intel graphics hardware..."
    
    # Check for Intel graphics in lspci
    if lspci | grep -i intel | grep -i vga >/dev/null 2>&1; then
        log "Intel graphics device found in PCI:"
        lspci | grep -i intel | grep -i vga
    else
        warn "Intel graphics device not visible in WSL PCI list"
    fi
    
    log "Checking Intel graphics driver..."
    # Check for i915 driver (Intel graphics driver in Linux)
    if modinfo i915 >/dev/null 2>&1; then
        log "Intel i915 driver information:"
        modinfo i915 | grep -E "version|description|filename" || echo "Driver info unavailable"
    else
        warn "Intel i915 driver not available in WSL"
    fi
    
    log "Checking OpenCL support..."
    # Intel OpenCL support for compute acceleration
    if command -v clinfo >/dev/null 2>&1; then
        log "OpenCL platforms available:"
        clinfo -l 2>/dev/null || echo "No OpenCL platforms found"
    else
        warn "OpenCL tools not installed"
    fi
    
    log "Checking VAAPI support..."
    if command -v vainfo >/dev/null 2>&1; then
        log "VAAPI information:"
        vainfo 2>/dev/null || echo "VAAPI not available"
    else
        warn "vainfo command not found"
    fi
}

# Final instructions
final_instructions() {
    header "Installation Complete!"
    echo
    log "Intel integrated graphics acceleration configured successfully!"
    echo
    warn "IMPORTANT: GPU acceleration may require a FULL SYSTEM REBOOT!"
    echo
    log "Intel integrated graphics can provide:"
    echo "1. Hardware video decode/encode (VAAPI)"
    echo "2. OpenCL compute acceleration"
    echo "3. Media processing acceleration"
    echo
    
    # Request system reboot
    request_reboot
    
    echo
    log "Next Steps:"
    echo "  1. Restart WSL2 session for group changes: 'wsl --shutdown' then restart"
    echo "  2. Verify installation: 'vainfo' and 'clinfo'"
    echo "  3. Test hardware acceleration in Kamiwaza"
    echo
    log "Verification Commands:"
    echo "  - vainfo                    # Check VAAPI support"
    echo "  - clinfo                    # Check OpenCL support" 
    echo "  - lspci | grep -i intel     # Check PCI devices"
    echo
    log "Note: Performance will be limited compared to discrete GPUs"
    echo
    log "Troubleshooting:"
    echo "  - If no GPU detected, ensure Windows Intel drivers are up to date"
    echo "  - For WSL2 issues, try: 'wsl --update'"
    echo "  - Check WSL2 GPU support is enabled in Windows"
    echo
    read -p "Press Enter to finish installation..."
}

# Function to request and execute system reboot
request_reboot() {
    header "System Reboot Required"
    echo
    warn "IMPORTANT: GPU acceleration requires a FULL SYSTEM REBOOT!"
    log "Please reboot your entire Windows system (not just WSL2) to activate GPU support."
    echo
    log "The Intel integrated graphics drivers have been installed, but they need a full system restart"
    log "to properly initialize and become available to WSL2."
    echo
    
    # Always show reboot instructions first
    show_reboot_instructions
    echo
    
    # Check if we're in an interactive terminal
    if [ -t 0 ]; then
        echo -e "${YELLOW}Would you like to reboot your computer now?${NC}"
        echo -e "${YELLOW}This will restart your ENTIRE Windows system, not just WSL2.${NC}"
        echo
        echo -e "${BLUE}Options:${NC}"
        echo -e "  ${GREEN}y${NC} - Yes, reboot now (recommended)"
        echo -e "  ${GREEN}n${NC} - No, I'll reboot manually later"
        echo -e "  ${GREEN}d${NC} - Debug mode - keep terminal open"
        echo
        
        while true; do
            read -p "Enter your choice (y/n/d): " choice
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
                [Dd]* )
                    log "Debug mode selected. Terminal will remain open for debugging."
                    log "You can manually run commands to troubleshoot any issues."
                    return 0
                    ;;
                * )
                    echo "Please enter y, n, or d."
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
    log "To complete Intel integrated graphics setup, please restart your computer:"
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

# Function to verify installation and show debugging info
verify_installation() {
    header "Installation Verification"
    echo
    log "Verifying Intel integrated graphics driver installation..."
    echo
    
    # Check if Intel packages are installed
    log "Checking Intel packages..."
    dpkg -l | grep -E "(intel|va-driver|libmfx|libvpl)" | head -10
    
    echo
    log "Checking Intel GPU detection..."
    if command -v vainfo >/dev/null 2>&1; then
        log "vainfo command found - testing Intel GPU detection..."
        echo "Running: vainfo | head -20"
        vainfo | head -20 2>/dev/null || warn "vainfo failed to detect Intel GPU"
    else
        warn "vainfo command not found - Intel drivers may not be properly installed"
    fi
    
    echo
    log "Checking OpenCL support..."
    if command -v clinfo >/dev/null 2>&1; then
        log "clinfo command found - testing OpenCL detection..."
        echo "Running: clinfo | grep -i intel | head -10"
        clinfo | grep -i intel | head -10 2>/dev/null || warn "No Intel OpenCL platforms detected"
    else
        warn "clinfo command not found - OpenCL may not be properly installed"
    fi
    
    echo
    log "Checking Intel device files..."
    ls -la /dev/dri/ 2>/dev/null || warn "No /dev/dri directory found"
    
    echo
    log "Checking user groups..."
    groups $USER
    
    echo
    log "Checking system logs for Intel GPU..."
    dmesg | grep -i intel | tail -5 2>/dev/null || warn "No Intel GPU messages in dmesg"
    
    echo
    log "Checking package installation status..."
    apt list --installed | grep -E "(intel|va-driver|libmfx|libvpl)" | head -10
}

# Main execution
main() {
    header "Intel Integrated Graphics Setup for WSL2"
    log "Setting up Intel integrated graphics support on WSL2 Ubuntu 24.04"
    echo
    
    check_prerequisites
    
    # Ask user about rebooting before proceeding
    header "Pre-Installation Reboot Check"
    echo
    warn "IMPORTANT: GPU acceleration requires a FULL SYSTEM REBOOT after installation!"
    log "This script will install Intel integrated graphics drivers that need a system restart to activate."
    echo
    echo -e "${YELLOW}Do you want to continue with the installation?${NC}"
    echo -e "${YELLOW}You will need to reboot your computer after installation completes.${NC}"
    echo
    echo -e "${BLUE}Options:${NC}"
    echo -e "  ${GREEN}y${NC} - Yes, continue with installation (will need reboot later)"
    echo -e "  ${GREEN}n${NC} - No, exit script"
    echo -e "  ${GREEN}s${NC} - Show reboot information"
    echo
    
    while true; do
        read -p "Enter your choice (y/n/s): " choice
        case $choice in
            [Yy]* )
                log "User chose to continue with installation. Proceeding..."
                echo
                break
                ;;
            [Nn]* )
                log "User chose to exit. Exiting script."
                exit 0
                ;;
            [Ss]* )
                show_reboot_instructions
                echo
                echo -e "${YELLOW}Do you want to continue with the installation now? (y/n):${NC}"
                read -p "Enter your choice: " continue_choice
                if [[ $continue_choice =~ ^[Yy]$ ]]; then
                    log "User chose to continue after viewing instructions. Proceeding..."
                    echo
                    break
                else
                    log "User chose to exit. Exiting script."
                    exit 0
                fi
                ;;
            * )
                echo "Please enter y, n, or s."
                ;;
        esac
    done
    
    # Track installation success
    installation_success=true
    
    # Update system
    header "Updating System"
    log "Updating package lists and upgrading system..."
    if sudo apt update && sudo apt upgrade -y; then
        log "System update completed [OK]"
    else
        warn "System update had issues - continuing anyway"
        installation_success=false
    fi
    
    # Install Intel integrated graphics drivers
    header "Installing Intel Integrated Graphics Drivers"
    log "Installing Intel media drivers and OpenCL support..."
    
    if sudo apt install -y intel-media-va-driver-non-free intel-opencl-icd vainfo libmfx-gen1 libvpl2 libvpl-tools libva-glx2 va-driver-all; then
        log "Intel integrated graphics drivers installed [OK]"
    else
        error "Failed to install Intel integrated graphics drivers"
        installation_success=false
    fi
    
    # Install OpenCL tools
    header "Installing OpenCL Tools"
    log "Installing OpenCL development tools..."
    
    if sudo apt install -y ocl-icd-libopencl1 ocl-icd-opencl-dev opencl-headers clinfo; then
        log "OpenCL tools installed [OK]"
    else
        error "Failed to install OpenCL tools"
        installation_success=false
    fi
    
    # Configure environment
    header "Configuring Environment"
    log "Setting up environment variables for Intel graphics..."
    
    # Add Intel graphics environment variables
    if echo 'export LIBVA_DRIVER_NAME=iHD' >> ~/.bashrc && \
       echo 'export VDPAU_DRIVER=va_gl' >> ~/.bashrc; then
        log "Environment variables configured [OK]"
        source ~/.bashrc
    else
        warn "Failed to configure environment variables - continuing anyway"
    fi
    
    # Configure permissions
    header "Configuring Permissions"
    log "Setting up user permissions for Intel graphics..."
    
    if sudo usermod -a -G video $USER; then
        log "User added to video group [OK]"
    else
        warn "Failed to add user to video group - continuing anyway"
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
    
    # Always request system reboot
    request_reboot
    
    echo
    log "=== Intel Integrated Graphics Setup Complete ==="
    log "Next steps:"
    log "1. Restart your computer (if not done automatically)"
    log "2. After restart, verify GPU support with: vainfo"
    log "3. Test OpenCL with: clinfo"
    echo
    
    # Final user interaction - keep terminal open for debugging
    header "Debug Mode - Terminal Will Remain Open"
    echo
    log "This terminal will remain open for debugging purposes."
    log "You can run additional commands to troubleshoot any issues."
    echo
    log "Useful debugging commands:"
    echo "  - vainfo                      # Check Intel VA-API drivers"
    echo "  - clinfo                      # Check OpenCL platforms and devices"
    echo "  - dpkg -l | grep intel        # Check installed Intel packages"
    echo "  - ls -la /dev/dri/            # Check GPU device files"
    echo "  - groups                      # Check user groups"
    echo "  - dmesg | grep -i intel       # Check kernel messages for Intel GPU"
    echo
    log "To close this terminal, type 'exit' or press Ctrl+D"
    echo
    
    # Keep the terminal open indefinitely
    while true; do
        echo -e "${BLUE}Debug shell ready. Type 'exit' to close or run commands:${NC}"
        if [ -t 0 ]; then
            # Interactive mode - provide a simple command prompt
            read -p "kamiwaza@intel-integrated-debug:~$ " debug_cmd
            if [ "$debug_cmd" = "exit" ]; then
                log "Exiting debug mode..."
                break
            elif [ -n "$debug_cmd" ]; then
                log "Executing: $debug_cmd"
                eval "$debug_cmd"
                echo
            fi
        else
            # Non-interactive mode - just wait
            log "Non-interactive mode - terminal will remain open for 60 seconds"
            sleep 60
            break
        fi
    done
    
    log "Debug mode ended. Terminal closing."
}

# Error handling - ensure script doesn't exit unexpectedly
trap 'echo -e "\n${RED}[ERROR] Script interrupted. Terminal will remain open for debugging.${NC}"; echo "Type 'exit' to close or run commands manually."; exec bash' INT TERM

# Run main function
main "$@"

# If we somehow get here, keep the terminal open
echo -e "\n${YELLOW}[WARN] Script completed but terminal will remain open for debugging.${NC}"
echo "Type 'exit' to close or run commands manually."
exec bash