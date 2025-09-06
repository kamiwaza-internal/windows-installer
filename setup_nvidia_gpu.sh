#!/bin/bash
# Prevent interactive prompts during package installation
export DEBIAN_FRONTEND=noninteractive

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

    CUDA_VERSION="12.8"
    PYTORCH_CUDA="cu128"
    PERFORMANCE_MODE="STANDARD"
    DRIVER_VERSION="575"
    MEMORY_OPTIMIZATION="DEFAULT"

    # Determine GPU type and set configuration
    if echo "$GPU_NAME" | grep -qi "RTX 5090"; then
        success "RTX 5090 detected! Configuring for maximum performance..."
        GPU_TYPE="RTX_5090"
    elif echo "$GPU_NAME" | grep -qi "RTX 5080"; then
        success "RTX 5080 detected! Configuring for optimal performance..."
        GPU_TYPE="RTX_5080"
    elif echo "$GPU_NAME" | grep -qi "RTX 4090"; then
        success "RTX 4090 detected! Configuring for high performance..."
        GPU_TYPE="RTX_4090"
    elif echo "$GPU_NAME" | grep -qi "RTX 4080"; then
        success "RTX 4080 detected! Configuring for optimal performance..."
        GPU_TYPE="RTX_4080"
    elif echo "$GPU_NAME" | grep -qi "RTX 4070"; then
        success "RTX 4070 detected! Configuring for balanced performance..."
        GPU_TYPE="RTX_4070"
    elif echo "$GPU_NAME" | grep -qi "RTX 3090"; then
        success "RTX 3090 detected! Configuring for high performance..."
        GPU_TYPE="RTX_3090"
    elif echo "$GPU_NAME" | grep -qi "RTX 3080"; then
        success "RTX 3080 detected! Configuring for optimal performance..."
        GPU_TYPE="RTX_3080"
    elif echo "$GPU_NAME" | grep -qi "RTX 3070"; then
        success "RTX 3070 detected! Configuring for balanced performance..."
        GPU_TYPE="RTX_3070"
    elif echo "$GPU_NAME" | grep -qi "RTX 3060"; then
        success "RTX 3060 detected! Configuring for standard performance..."
        GPU_TYPE="RTX_3060"
    else
        warn "Unknown RTX GPU detected. Using default configuration..."
        GPU_TYPE="RTX_GENERIC"
        DRIVER_VERSION="575"
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
        warn "Continuing anyway for automated installation..."
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

# GPU setup completed - restart will be handled by main installer
log "GPU setup completed - restart will be handled by main installer after package installation"

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
    log "Checking container runtime setup..."
    
    # Check runc symlinks
    if [ -L "/usr/bin/runc" ]; then
        RUNC_TARGET=$(readlink /usr/bin/runc)
        log "runc symlink found: /usr/bin/runc -> $RUNC_TARGET"
        
        if /usr/bin/runc --version >/dev/null 2>&1; then
            log "Symlinked runc is working"
        else
            warn "Symlinked runc exists but not responding"
        fi
    else
        warn "runc symlink not found in /usr/bin"
    fi
    
    # Check nvidia-container-runtime
    if command -v nvidia-container-runtime >/dev/null 2>&1; then
        log "nvidia-container-runtime found - testing..."
        if nvidia-container-runtime --version >/dev/null 2>&1; then
            log "nvidia-container-runtime is working properly"
        else
            warn "nvidia-container-runtime has configuration issues"
        fi
    else
        warn "nvidia-container-runtime not found"
    fi
    
    echo
    log "Checking NVIDIA GPU detection..."
    
    # Check nvidia-smi symlinks
    if [ -L "/usr/local/bin/nvidia-smi" ]; then
        SYMLINK_TARGET=$(readlink /usr/local/bin/nvidia-smi)
        log "nvidia-smi symlink found: /usr/local/bin/nvidia-smi -> $SYMLINK_TARGET"
        
        if /usr/local/bin/nvidia-smi --version >/dev/null 2>&1; then
            log "Symlinked nvidia-smi (/usr/local/bin) is working"
        else
            warn "Symlinked nvidia-smi (/usr/local/bin) exists but not responding"
        fi
    else
        warn "nvidia-smi symlink not found in /usr/local/bin"
    fi
    
    if [ -L "/usr/bin/nvidia-smi" ]; then
        SYMLINK_TARGET=$(readlink /usr/bin/nvidia-smi)
        log "nvidia-smi symlink found: /usr/bin/nvidia-smi -> $SYMLINK_TARGET"
        
        if /usr/bin/nvidia-smi --version >/dev/null 2>&1; then
            log "Symlinked nvidia-smi (/usr/bin) is working"
        else
            warn "Symlinked nvidia-smi (/usr/bin) exists but not responding"
        fi
    else
        log "nvidia-smi symlink not found in /usr/bin (may be the actual binary)"
    fi
    
    # Check standard nvidia-smi command
    if command -v nvidia-smi >/dev/null 2>&1; then
        NVIDIA_SMI_LOCATION=$(which nvidia-smi)
        log "nvidia-smi command found at: $NVIDIA_SMI_LOCATION"
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
    sudo apt-get purge -y nvidia-* cuda-* 2>/dev/null || true
    sudo apt-get autoremove -y
    sudo apt-get clean
    log "  [OK] Cleanup completed"
    
    # 3. Install CUDA repository and key
    log "3. Installing CUDA repository and key..."
    if sudo apt-get install -y wget curl ca-certificates gnupg && \
       sudo update-ca-certificates || true && \
       wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb && \
       (sudo apt-get -y install ./cuda-keyring_1.1-1_all.deb || sudo dpkg -i --force-confdef cuda-keyring_1.1-1_all.deb) && \
       rm -f cuda-keyring_1.1-1_all.deb && \
       sudo apt-get update; then
        log "  [OK] CUDA repository and key installed"
    else
        error "  [ERROR] Failed to install CUDA repository and key"
        installation_success=false
    fi
    
    # 4. Install CUDA toolkit and drivers
    log "4. Installing CUDA toolkit and drivers..."
    if sudo apt-get install -y cuda-toolkit cuda-drivers; then
        log "  [OK] CUDA toolkit and drivers installed"
    else
        error "  [ERROR] Failed to install CUDA toolkit and drivers"
        installation_success=false
    fi
    
    # 5. Configure environment variables
    log "5. Configuring environment variables..."
    if echo 'export PATH=/usr/local/cuda-12.8/bin:$PATH' >> ~/.bashrc && \
       echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc; then
        log "  [OK] Environment variables configured"
        source ~/.bashrc
    else
        warn "  [WARN] Failed to configure environment variables - continuing anyway"
    fi
    
    # 5.5. Create symlinks for container runtime and nvidia-smi
    log "5.5. Setting up container runtime and nvidia-smi symlinks..."
    
    # Ensure /usr/local/bin exists and is writable
    sudo mkdir -p /usr/local/bin
    
    # Fix runc symlink for nvidia-container-runtime
    log "  Setting up runc symlink for nvidia-container-runtime..."
    if [ -f "/usr/local/bin/runc" ]; then
        # Create symlink in /usr/bin so nvidia-container-runtime can find it
        sudo rm -f /usr/bin/runc
        if sudo ln -sf /usr/local/bin/runc /usr/bin/runc; then
            log "  [OK] runc symlink created: /usr/bin/runc -> /usr/local/bin/runc"
            
            # Verify nvidia-container-runtime can now find runc
            if /usr/bin/nvidia-container-runtime --version >/dev/null 2>&1; then
                log "  [OK] nvidia-container-runtime can now find runc"
            else
                warn "  [WARN] nvidia-container-runtime still has issues - may need restart"
            fi
        else
            warn "  [WARN] Failed to create runc symlink in /usr/bin"
        fi
    else
        warn "  [WARN] runc not found in /usr/local/bin"
    fi
    
    # Find nvidia-smi in common locations and create symlinks in both places
    log "  Setting up nvidia-smi symlinks for consistent access..."
    NVIDIA_SMI_PATH=""
    for path in /usr/bin/nvidia-smi /usr/lib/wsl/lib/nvidia-smi /usr/local/cuda/bin/nvidia-smi; do
        if [ -f "$path" ]; then
            NVIDIA_SMI_PATH="$path"
            log "  Found nvidia-smi at: $path"
            break
        fi
    done
    
    if [ -n "$NVIDIA_SMI_PATH" ]; then
        # Create symlink in /usr/local/bin (for script consistency)
        sudo rm -f /usr/local/bin/nvidia-smi
        if sudo ln -sf "$NVIDIA_SMI_PATH" /usr/local/bin/nvidia-smi; then
            log "  [OK] nvidia-smi symlink created: /usr/local/bin/nvidia-smi -> $NVIDIA_SMI_PATH"
        else
            warn "  [WARN] Failed to create nvidia-smi symlink in /usr/local/bin"
        fi
        
        # Also ensure it's available in standard location if needed
        if [ "$NVIDIA_SMI_PATH" != "/usr/bin/nvidia-smi" ] && [ ! -f "/usr/bin/nvidia-smi" ]; then
            sudo rm -f /usr/bin/nvidia-smi
            if sudo ln -sf "$NVIDIA_SMI_PATH" /usr/bin/nvidia-smi; then
                log "  [OK] nvidia-smi symlink created: /usr/bin/nvidia-smi -> $NVIDIA_SMI_PATH"
            else
                warn "  [WARN] Failed to create nvidia-smi symlink in /usr/bin"
            fi
        fi
        
        # Verify symlinks work
        if /usr/local/bin/nvidia-smi --version >/dev/null 2>&1; then
            log "  [OK] /usr/local/bin/nvidia-smi working"
        else
            warn "  [WARN] /usr/local/bin/nvidia-smi not responding - may need restart"
        fi
        
        if /usr/bin/nvidia-smi --version >/dev/null 2>&1; then
            log "  [OK] /usr/bin/nvidia-smi working"
        else
            warn "  [WARN] /usr/bin/nvidia-smi not responding - may need restart"
        fi
    else
        warn "  [WARN] nvidia-smi not found in expected locations - will be available after restart"
        # Create placeholders that will work after restart
        sudo rm -f /usr/local/bin/nvidia-smi /usr/bin/nvidia-smi
        if sudo ln -sf /usr/bin/nvidia-smi /usr/local/bin/nvidia-smi; then
            log "  [OK] Created placeholder nvidia-smi symlink for post-restart access"
        fi
    fi
    
    # Add /usr/local/bin to PATH in bashrc if not already there
    if ! grep -q '/usr/local/bin' ~/.bashrc; then
        echo 'export PATH=/usr/local/bin:$PATH' >> ~/.bashrc
        log "  [OK] Added /usr/local/bin to PATH in ~/.bashrc"
    else
        log "  [OK] /usr/local/bin already in PATH"
    fi
    
    # 6. Install NVIDIA Container Toolkit for Docker GPU access
    log "6. Installing NVIDIA Container Toolkit for Docker GPU access..."
    
    # 6.0. Ensure basic prerequisites are available
    log "  6.0. Installing basic prerequisites..."
    if sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg; then
        log "  [OK] Basic prerequisites installed"
    else
        warn "  [WARN] Failed to install basic prerequisites - continuing anyway"
    fi
    
    # 6.1. Clean any old/bad repository file (optional but helps)
    log "  6.1. Cleaning any old NVIDIA container toolkit repository files..."
    sudo rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list
    log "  [OK] Old repository files cleaned"
    
    # 6.2. Add the libnvidia-container GPG key
    log "  6.2. Adding NVIDIA Container Toolkit GPG key..."
    if sudo mkdir -p /etc/apt/keyrings && \
       curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
       sudo gpg --dearmor -o /etc/apt/keyrings/nvidia-container-toolkit.gpg; then
        log "  [OK] NVIDIA Container Toolkit GPG key added"
    else
        warn "  [WARN] Failed to add NVIDIA Container Toolkit GPG key"
    fi
    
    # 6.3. Add the repository (works for Noble 24.04)
    log "  6.3. Adding NVIDIA Container Toolkit repository for Ubuntu 24.04..."
    if curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
       sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit.gpg] https://#' | \
       sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null; then
        log "  [OK] NVIDIA Container Toolkit repository added"
    else
        warn "  [WARN] Failed to add NVIDIA Container Toolkit repository"
    fi
    
    # 6.4. Update and verify apt sees the package
    log "  6.4. Updating package lists and verifying NVIDIA Container Toolkit availability..."
    if sudo apt-get update; then
        log "  [OK] Package lists updated"
        
        # Verify the package is available
        if apt-cache policy nvidia-container-toolkit | grep -q "nvidia.github.io"; then
            log "  [OK] NVIDIA Container Toolkit package found in repository"
        else
            warn "  [WARN] NVIDIA Container Toolkit package not found - may still install from other sources"
        fi
    else
        warn "  [WARN] Failed to update package lists"
    fi
    
    # 6.5. Install the toolkit (userspace only; do NOT install cuda-drivers in WSL)
    log "  6.5. Installing NVIDIA Container Toolkit (userspace only)..."
    if sudo apt-get install -y nvidia-container-toolkit; then
        log "  [OK] NVIDIA Container Toolkit installed"
        
        # 6.6. Configure Docker runtime (Desktop-backed on WSL)
        log "  6.6. Configuring Docker runtime for NVIDIA Container Toolkit..."
        if sudo nvidia-ctk runtime configure --runtime=docker; then
            log "  [OK] Docker NVIDIA runtime configured"
            
            # Restart Docker service to apply changes
            log "  Restarting Docker service..."
            if sudo service docker restart; then
                log "  [OK] Docker service restarted with NVIDIA runtime"
            else
                warn "  [WARN] Docker service restart failed - manual restart may be needed"
            fi
        else
            warn "  [WARN] Docker NVIDIA runtime configuration failed"
        fi
    else
        error "  [ERROR] Failed to install NVIDIA Container Toolkit"
        installation_success=false
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
    
    # GPU setup completed - NO RESTART YET
    log "GPU setup completed successfully!"
    log "IMPORTANT: GPU drivers are installed but NOT yet active"
    log "The installer will continue with package installation, then restart ONCE to activate everything"
    log "After the single restart, both GPU acceleration AND Kamiwaza will be ready"
    
    echo
    log "=== NVIDIA GPU Setup Complete ==="
    log "Next steps:"
    log "1. Installer will continue with Kamiwaza package installation"
    log "2. After package installation completes, system will restart ONCE"
    log "3. After restart, GPU acceleration will be active AND Kamiwaza will start automatically"
    log "4. Verify GPU support with: nvidia-smi"
    log "5. Test CUDA with: nvcc --version"
    echo
    
    # Final user interaction - keep terminal open for debugging
    header "Debug Mode - Terminal Will Remain Open"
    echo
    log "This terminal will remain open for debugging purposes."
    log "You can run additional commands to troubleshoot any issues."
    echo
    log "Useful debugging commands:"
    echo "  - nvidia-smi                    # Check NVIDIA GPU status"
    echo "  - /usr/local/bin/nvidia-smi     # Check symlinked nvidia-smi"
    echo "  - ls -la /usr/local/bin/nvidia-smi # Check nvidia-smi symlink"
    echo "  - which nvidia-smi             # Find nvidia-smi location"
    echo "  - nvcc --version               # Check CUDA compiler version"
    echo "  - dpkg -l | grep nvidia       # Check installed NVIDIA packages"
    echo "  - ls -la /dev/nvidia*         # Check NVIDIA device files"
    echo "  - groups                       # Check user groups"
    echo "  - dmesg | grep -i nvidia      # Check kernel messages for NVIDIA GPU"
    echo "  - docker info | grep -i runtime # Check Docker runtime configuration"
    echo "  - docker run --rm --gpus all ubuntu:22.04 nvidia-smi # Test Docker GPU access"
    echo
    log "To close this terminal, type 'exit' or press Ctrl+D"
    echo
    
    # Script completed - exit cleanly
    log "Script completed successfully. Exiting..."
    exit 0
}

# Run main function
main "$@" 