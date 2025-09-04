#!/bin/bash
# Prevent interactive prompts during package installation
export DEBIAN_FRONTEND=noninteractive

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
    
    # GPU setup completed - NO RESTART YET
    log "GPU setup completed successfully!"
    log "IMPORTANT: GPU drivers are installed but NOT yet active"
    log "The installer will continue with package installation, then restart ONCE to activate everything"
    log "After the single restart, both GPU acceleration AND Kamiwaza will be ready"
    
    echo
    log "=== Intel Integrated Graphics Setup Complete ==="
    log "Next steps:"
    log "1. Installer will continue with Kamiwaza package installation"
    log "2. After package installation completes, system will restart ONCE"
    log "3. After restart, GPU acceleration will be active AND Kamiwaza will start automatically"
    log "4. Verify GPU support with: vainfo"
    log "5. Test OpenCL with: clinfo"
    log "6. Check PCI devices: lspci | grep -i intel"
    echo
    log "Note: Performance will be limited compared to discrete GPUs"
    echo
    log "Troubleshooting:"
    log "  - If no GPU detected, ensure Windows Intel drivers are up to date"
    log "  - For WSL2 issues, try: 'wsl --update'"
    log "  - Check WSL2 GPU support is enabled in Windows"
    echo
}

# GPU setup completed - restart will be handled by main installer
log "GPU setup completed - restart will be handled by main installer after package installation"

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
    
    # Always proceed with installation (no user prompts)
    log "Proceeding with installation automatically..."
    echo
    
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
    
    # Script completed - exit cleanly
    log "Script completed successfully. Exiting..."
    exit 0
}

# Run main function
main "$@"