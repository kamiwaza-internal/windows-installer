#!/bin/bash
# Continue on errors instead of exiting
# NVIDIA GPU Setup Script for WSL2 Ubuntu 24.04 (Noble)
# Designed for NVIDIA GeForce RTX 30xx, 40xx, and 50xx series GPUs
# Runs as kamiwaza user with passwordless sudo access

echo "=== NVIDIA GeForce RTX GPU Configuration ==="
echo "Setting up NVIDIA GPU acceleration for Kamiwaza..."
echo "Timestamp: $(date)"
echo "Running as user: $(whoami)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
}

# GPU detection and configuration
detect_gpu() {
    header "GPU Detection"
    
    # Check if nvidia-smi is available
    if ! command -v nvidia-smi &> /dev/null; then
        warn "nvidia-smi not found. Will install NVIDIA utilities first."
        return 1
    fi
    
    # Get GPU information
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits 2>/dev/null)
    
    if [ -z "$GPU_INFO" ]; then
        warn "Could not detect GPU information. Continuing with generic setup..."
        return 1
    fi
    
    # Parse GPU information
    GPU_NAME=$(echo "$GPU_INFO" | cut -d',' -f1 | xargs)
    GPU_MEMORY=$(echo "$GPU_INFO" | cut -d',' -f2 | xargs)
    DRIVER_VERSION=$(echo "$GPU_INFO" | cut -d',' -f3 | xargs)
    
    log "Detected GPU: $GPU_NAME"
    log "GPU Memory: $GPU_MEMORY MB"
    log "Driver Version: $DRIVER_VERSION"
    
    # Determine GPU type and set configuration
    if echo "$GPU_NAME" | grep -qi "RTX 5090"; then
        success "RTX 5090 detected! Configuring for maximum performance..."
        GPU_TYPE="RTX_5090"
        CUDA_VERSION="12.8"
        PYTORCH_CUDA="cu128"
        MEMORY_OPTIMIZATION="24GB"
        PERFORMANCE_MODE="MAXIMUM"
        DRIVER_VERSION="575"
    elif echo "$GPU_NAME" | grep -qi "RTX 5080"; then
        success "RTX 5080 detected! Configuring for optimal performance..."
        GPU_TYPE="RTX_5080"
        CUDA_VERSION="12.8"
        PYTORCH_CUDA="cu128"
        MEMORY_OPTIMIZATION="16GB"
        PERFORMANCE_MODE="OPTIMAL"
        DRIVER_VERSION="575"
    elif echo "$GPU_NAME" | grep -qi "RTX 4090"; then
        success "RTX 4090 detected! Configuring for high performance..."
        GPU_TYPE="RTX_4090"
        CUDA_VERSION="12.4"
        PYTORCH_CUDA="cu124"
        MEMORY_OPTIMIZATION="24GB"
        PERFORMANCE_MODE="HIGH"
        DRIVER_VERSION="550"
    elif echo "$GPU_NAME" | grep -qi "RTX 4080"; then
        success "RTX 4080 detected! Configuring for optimal performance..."
        GPU_TYPE="RTX_4080"
        CUDA_VERSION="12.4"
        PYTORCH_CUDA="cu124"
        MEMORY_OPTIMIZATION="16GB"
        PERFORMANCE_MODE="OPTIMAL"
        DRIVER_VERSION="550"
    elif echo "$GPU_NAME" | grep -qi "RTX 4070"; then
        success "RTX 4070 detected! Configuring for balanced performance..."
        GPU_TYPE="RTX_4070"
        CUDA_VERSION="12.4"
        PYTORCH_CUDA="cu124"
        MEMORY_OPTIMIZATION="12GB"
        PERFORMANCE_MODE="BALANCED"
        DRIVER_VERSION="550"
    elif echo "$GPU_NAME" | grep -qi "RTX 3090"; then
        success "RTX 3090 detected! Configuring for high performance..."
        GPU_TYPE="RTX_3090"
        CUDA_VERSION="12.2"
        PYTORCH_CUDA="cu122"
        MEMORY_OPTIMIZATION="24GB"
        PERFORMANCE_MODE="HIGH"
        DRIVER_VERSION="525"
    elif echo "$GPU_NAME" | grep -qi "RTX 3080"; then
        success "RTX 3080 detected! Configuring for optimal performance..."
        GPU_TYPE="RTX_3080"
        CUDA_VERSION="12.2"
        PYTORCH_CUDA="cu122"
        MEMORY_OPTIMIZATION="10GB"
        PERFORMANCE_MODE="OPTIMAL"
        DRIVER_VERSION="525"
    elif echo "$GPU_NAME" | grep -qi "RTX 3070"; then
        success "RTX 3070 detected! Configuring for balanced performance..."
        GPU_TYPE="RTX_3070"
        CUDA_VERSION="12.2"
        PYTORCH_CUDA="cu122"
        MEMORY_OPTIMIZATION="8GB"
        PERFORMANCE_MODE="BALANCED"
        DRIVER_VERSION="525"
    elif echo "$GPU_NAME" | grep -qi "RTX 3060"; then
        success "RTX 3060 detected! Configuring for standard performance..."
        GPU_TYPE="RTX_3060"
        CUDA_VERSION="12.2"
        PYTORCH_CUDA="cu122"
        MEMORY_OPTIMIZATION="12GB"
        PERFORMANCE_MODE="STANDARD"
        DRIVER_VERSION="525"
    else
        warn "Unknown RTX GPU detected. Using default configuration..."
        GPU_TYPE="RTX_GENERIC"
        CUDA_VERSION="12.4"
        PYTORCH_CUDA="cu124"
        MEMORY_OPTIMIZATION="DEFAULT"
        PERFORMANCE_MODE="DEFAULT"
        DRIVER_VERSION="550"
    fi
    
    echo
    log "GPU Configuration:"
    echo "  Type: $GPU_TYPE"
    echo "  CUDA Version: $CUDA_VERSION"
    echo "  PyTorch CUDA: $PYTORCH_CUDA"
    echo "  Memory Optimization: $MEMORY_OPTIMIZATION"
    echo "  Performance Mode: $PERFORMANCE_MODE"
    echo "  Recommended Driver: $DRIVER_VERSION"
    echo
}

# GPU-specific optimizations based on performance tier
configure_gpu_optimizations() {
    case "$GPU_TYPE" in
        "RTX_5090"|"RTX_4090"|"RTX_3090")
            header "High-End GPU Optimizations (24GB VRAM)"
            log "Configuring $GPU_TYPE for maximum performance..."
            
            # Set environment variables for high-end GPUs
            export CUDA_VISIBLE_DEVICES=0
            export CUDA_LAUNCH_BLOCKING=0
            export CUDA_CACHE_DISABLE=0
            export CUDA_CACHE_PATH=/tmp/cuda_cache
            
            # Create CUDA cache directory
            sudo mkdir -p /tmp/cuda_cache
            sudo chmod 777 /tmp/cuda_cache
            
            # Optimize memory management for 24GB VRAM
            log "Optimizing memory management for 24GB VRAM..."
            sudo sysctl -w vm.max_map_count=2147483647
            sudo sysctl -w vm.swappiness=10
            
            # Set GPU memory fraction for better utilization
            export TF_FORCE_GPU_ALLOW_GROWTH=true
            export TF_GPU_MEMORY_FRACTION=0.95
            
            # High-end GPU specific PyTorch optimizations
            export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
            export TORCH_CUDNN_V8_API_ENABLED=1
            export TORCH_CUDNN_V8_API_DISABLED=0
            
            success "$GPU_TYPE optimizations applied!"
            ;;
            
        "RTX_5080"|"RTX_4080"|"RTX_3080")
            header "Mid-High GPU Optimizations (16GB/10GB VRAM)"
            log "Configuring $GPU_TYPE for optimal performance..."
            
            # Set environment variables for mid-high GPUs
            export CUDA_VISIBLE_DEVICES=0
            export CUDA_LAUNCH_BLOCKING=0
            export CUDA_CACHE_DISABLE=0
            export CUDA_CACHE_PATH=/tmp/cuda_cache
            
            # Create CUDA cache directory
            sudo mkdir -p /tmp/cuda_cache
            sudo chmod 777 /tmp/cuda_cache
            
            # Optimize memory management
            log "Optimizing memory management..."
            sudo sysctl -w vm.max_map_count=1073741824
            sudo sysctl -w vm.swappiness=20
            
            # Set GPU memory fraction for better utilization
            export TF_FORCE_GPU_ALLOW_GROWTH=true
            export TF_GPU_MEMORY_FRACTION=0.90
            
            # Mid-high GPU specific PyTorch optimizations
            export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:256
            export TORCH_CUDNN_V8_API_ENABLED=1
            
            success "$GPU_TYPE optimizations applied!"
            ;;
            
        "RTX_4070"|"RTX_3070")
            header "Mid-Range GPU Optimizations (12GB/8GB VRAM)"
            log "Configuring $GPU_TYPE for balanced performance..."
            
            # Set environment variables for mid-range GPUs
            export CUDA_VISIBLE_DEVICES=0
            export CUDA_LAUNCH_BLOCKING=0
            export CUDA_CACHE_DISABLE=0
            export CUDA_CACHE_PATH=/tmp/cuda_cache
            
            # Create CUDA cache directory
            sudo mkdir -p /tmp/cuda_cache
            sudo chmod 777 /tmp/cuda_cache
            
            # Optimize memory management
            log "Optimizing memory management..."
            sudo sysctl -w vm.max_map_count=536870912
            sudo sysctl -w vm.swappiness=30
            
            # Set GPU memory fraction for better utilization
            export TF_FORCE_GPU_ALLOW_GROWTH=true
            export TF_GPU_MEMORY_FRACTION=0.85
            
            # Mid-range GPU specific PyTorch optimizations
            export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128
            export TORCH_CUDNN_V8_API_ENABLED=1
            
            success "$GPU_TYPE optimizations applied!"
            ;;
            
        "RTX_3060")
            header "Entry-Level GPU Optimizations (12GB VRAM)"
            log "Configuring $GPU_TYPE for standard performance..."
            
            # Set environment variables for entry-level GPUs
            export CUDA_VISIBLE_DEVICES=0
            export CUDA_LAUNCH_BLOCKING=0
            export CUDA_CACHE_DISABLE=0
            export CUDA_CACHE_PATH=/tmp/cuda_cache
            
            # Create CUDA cache directory
            sudo mkdir -p /tmp/cuda_cache
            sudo chmod 777 /tmp/cuda_cache
            
            # Optimize memory management
            log "Optimizing memory management..."
            sudo sysctl -w vm.max_map_count=268435456
            sudo sysctl -w vm.swappiness=40
            
            # Set GPU memory fraction for better utilization
            export TF_FORCE_GPU_ALLOW_GROWTH=true
            export TF_GPU_MEMORY_FRACTION=0.80
            
            # Entry-level GPU specific PyTorch optimizations
            export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:64
            export TORCH_CUDNN_V8_API_ENABLED=1
            
            success "$GPU_TYPE optimizations applied!"
            ;;
            
        *)
            header "Generic GPU Optimizations"
            log "Configuring generic GPU settings..."
            
            # Basic environment variables
            export CUDA_VISIBLE_DEVICES=0
            export CUDA_LAUNCH_BLOCKING=0
            export TF_FORCE_GPU_ALLOW_GROWTH=true
            export TF_GPU_MEMORY_FRACTION=0.75
            
            # Create CUDA cache directory
            sudo mkdir -p /tmp/cuda_cache
            sudo chmod 777 /tmp/cuda_cache
            
            success "Generic GPU optimizations applied!"
            ;;
    esac
    echo
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
    log "WSL2 environment detected [OK]"
}

# Check Ubuntu version
check_ubuntu_version() {
    if ! lsb_release -d | grep -q "Ubuntu 24.04"; then
        warn "This script is optimized for Ubuntu 24.04. Your version: $(lsb_release -d | cut -f2)"
        warn "Continuing with installation..."
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
    log "2. Updated NVIDIA GPU drivers from NVIDIA's official site"
    log "3. NVIDIA GeForce RTX 5080/5090 GPU"
    log "4. Ubuntu 24.04 (Noble) with Python 3.12"
    echo
}

# Function to request and execute system reboot
request_reboot() {
    header "System Reboot Required"
    echo
    warn "IMPORTANT: GPU acceleration requires a FULL SYSTEM REBOOT!"
    log "Please reboot your entire Windows system (not just WSL2) to activate GPU support."
    echo
    log "The NVIDIA GPU drivers have been installed, but they need a full system restart"
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
    log "To complete NVIDIA GPU setup, please restart your computer:"
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
    log "Verifying NVIDIA GPU driver installation..."
    echo
    
    # Check if NVIDIA packages are installed
    log "Checking NVIDIA packages..."
    dpkg -l | grep -E "(nvidia|cuda)" | head -10
    
    echo
    log "Checking NVIDIA GPU detection..."
    if command -v nvidia-smi >/dev/null 2>&1; then
        log "nvidia-smi command found - testing GPU detection..."
        echo "Running: nvidia-smi --query-gpu=name,driver_version --format=csv,noheader"
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || warn "nvidia-smi failed to detect GPU"
    else
        warn "nvidia-smi command not found - NVIDIA drivers may not be properly installed"
    fi
    
    echo
    log "Checking NVIDIA device files..."
    ls -la /dev/nvidia* 2>/dev/null || warn "No NVIDIA device files found"
    
    echo
    log "Checking user groups..."
    groups $USER
    
    echo
    log "Checking system logs for NVIDIA GPU..."
    dmesg | grep -i nvidia | tail -5 2>/dev/null || warn "No NVIDIA GPU messages in dmesg"
    
    echo
    log "Checking package installation status..."
    apt list --installed | grep -E "(nvidia|cuda)" | head -10
    
    echo
    log "Checking CUDA availability..."
    if command -v nvcc >/dev/null 2>&1; then
        log "CUDA compiler found - checking version..."
        nvcc --version 2>/dev/null || warn "nvcc version check failed"
    else
        warn "CUDA compiler not found - CUDA may not be properly installed"
    fi
}

# Main execution
main() {
    header "NVIDIA GPU CUDA Setup for WSL2"
    log "Setting up CUDA support for NVIDIA RTX GPU on WSL2 Ubuntu 24.04 (Noble)"
    log "Using NVIDIA's official CUDA repository for Ubuntu 24.04"
    echo
    
    check_prerequisites
    
    # Ask user about rebooting before proceeding
    header "Pre-Installation Reboot Check"
    echo
    warn "IMPORTANT: GPU acceleration requires a FULL SYSTEM REBOOT after installation!"
    log "This script will install NVIDIA GPU drivers that need a system restart to activate."
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
    sudo apt-get purge -y nvidia-* cuda-* 2>/dev/null || true
    sudo apt-get autoremove -y
    sudo apt-get clean
    log "  [OK] Cleanup completed"
    
    # 3. Install CUDA repository and key
    log "3. Installing CUDA repository and key..."
    if sudo apt-get install -y wget gpg && \
       wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb && \
       sudo dpkg -i cuda-keyring_1.1-1_all.deb && \
       sudo apt-get update; then
        log "  [OK] CUDA repository and key installed"
    else
        error "  [ERROR] Failed to install CUDA repository and key"
        installation_success=false
    fi
    
    # 4. Install CUDA toolkit and drivers
    log "4. Installing CUDA toolkit and drivers..."
    if sudo apt-get install -y cuda-toolkit-12-4 cuda-drivers; then
        log "  [OK] CUDA toolkit and drivers installed"
    else
        error "  [ERROR] Failed to install CUDA toolkit and drivers"
        installation_success=false
    fi
    
    # 5. Configure environment variables
    log "5. Configuring environment variables..."
    if echo 'export PATH=/usr/local/cuda-12.4/bin:$PATH' >> ~/.bashrc && \
       echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc; then
        log "  [OK] Environment variables configured"
        source ~/.bashrc
    else
        warn "  [WARN] Failed to configure environment variables - continuing anyway"
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
    log "=== NVIDIA GPU Setup Complete ==="
    log "Next steps:"
    log "1. Restart your computer (if not done automatically)"
    log "2. After restart, verify GPU support with: nvidia-smi"
    log "3. Test CUDA with: nvcc --version"
    echo
    
    # Final user interaction - keep terminal open for debugging
    header "Debug Mode - Terminal Will Remain Open"
    echo
    log "This terminal will remain open for debugging purposes."
    log "You can run additional commands to troubleshoot any issues."
    echo
    log "Useful debugging commands:"
    echo "  - nvidia-smi                    # Check NVIDIA GPU status"
    echo "  - nvcc --version               # Check CUDA compiler version"
    echo "  - dpkg -l | grep nvidia       # Check installed NVIDIA packages"
    echo "  - ls -la /dev/nvidia*         # Check NVIDIA device files"
    echo "  - groups                       # Check user groups"
    echo "  - dmesg | grep -i nvidia      # Check kernel messages for NVIDIA GPU"
    echo
    log "To close this terminal, type 'exit' or press Ctrl+D"
    echo
    
    # Keep the terminal open indefinitely
    while true; do
        echo -e "${BLUE}Debug shell ready. Type 'exit' to close or run commands:${NC}"
        if [ -t 0 ]; then
            # Interactive mode - provide a simple command prompt
            read -p "kamiwaza@nvidia-gpu-debug:~$ " debug_cmd
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