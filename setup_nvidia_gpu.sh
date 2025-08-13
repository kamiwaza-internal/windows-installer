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

# Main execution following the exact order specified
main() {
    header "NVIDIA GPU Setup for WSL2"
    log "Setting up NVIDIA GeForce RTX GPU support on WSL2 Ubuntu 24.04 (Noble)"
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
    
    # Detect GPU and configure accordingly
    detect_gpu
    
    # Step 1: Update package lists
    header "Step 1: Updating Package Lists"
    log "Running: sudo apt update"
    sudo apt update
    
    # Step 2: Install nvidia-utils based on GPU type
    header "Step 2: Installing nvidia-utils-$DRIVER_VERSION"
    log "Installing nvidia-utils-$DRIVER_VERSION for $GPU_TYPE"
    log "Running: sudo apt install nvidia-utils-$DRIVER_VERSION"
    sudo apt install nvidia-utils-$DRIVER_VERSION
    
    # Step 2.1: Ensure nvidia-smi is accessible to all users
    header "Step 2.1: Configuring nvidia-smi for All Users"
    log "Setting up nvidia-smi accessibility for all users..."
    
    # Check if nvidia-smi exists and get its location
    NVIDIA_SMI_PATH=$(which nvidia-smi 2>/dev/null)
    if [ -z "$NVIDIA_SMI_PATH" ]; then
        # Try common locations
        for path in /usr/bin/nvidia-smi /usr/local/bin/nvidia-smi /opt/nvidia/bin/nvidia-smi; do
            if [ -f "$path" ]; then
                NVIDIA_SMI_PATH="$path"
                break
            fi
        done
    fi
    
    if [ -n "$NVIDIA_SMI_PATH" ]; then
        log "Found nvidia-smi at: $NVIDIA_SMI_PATH"
        
        # Ensure it's executable by all users
        sudo chmod 755 "$NVIDIA_SMI_PATH"
        log "Set executable permissions on nvidia-smi"
        
        # Create symbolic link in /usr/local/bin if not already there
        if [ "$NVIDIA_SMI_PATH" != "/usr/local/bin/nvidia-smi" ]; then
            sudo ln -sf "$NVIDIA_SMI_PATH" /usr/local/bin/nvidia-smi
            log "Created symbolic link in /usr/local/bin"
        fi
        
        # Add /usr/local/bin to PATH for all users if not already present
        if ! grep -q "/usr/local/bin" /etc/environment; then
            echo 'PATH="/usr/local/bin:$PATH"' | sudo tee -a /etc/environment
            log "Added /usr/local/bin to system PATH"
        fi
        
        # Create a wrapper script for better user access
        sudo tee /usr/local/bin/nvidia-smi-wrapper > /dev/null << 'EOF'
#!/bin/bash
# Wrapper script for nvidia-smi to ensure proper access
export PATH="/usr/local/bin:$PATH"

# Check if running as root or with sudo
if [ "$EUID" -eq 0 ]; then
    exec nvidia-smi "$@"
else
    # Try to run with sudo if not root
    if command -v sudo >/dev/null 2>&1; then
        exec sudo nvidia-smi "$@"
    else
        exec nvidia-smi "$@"
    fi
fi
EOF
        
        sudo chmod 755 /usr/local/bin/nvidia-smi-wrapper
        log "Created nvidia-smi wrapper script"
        
        # Test nvidia-smi accessibility
        log "Testing nvidia-smi accessibility..."
        if timeout 10s nvidia-smi --query-gpu=name --format=csv,noheader >/dev/null 2>&1; then
            success "nvidia-smi is accessible and working!"
        else
            warn "nvidia-smi may require sudo access. Testing with sudo..."
            if timeout 10s sudo nvidia-smi --query-gpu=name --format=csv,noheader >/dev/null 2>&1; then
                success "nvidia-smi works with sudo access"
            else
                error "nvidia-smi is not working properly"
            fi
        fi
        
    else
        error "Could not locate nvidia-smi after installation"
        warn "Continuing with installation..."
    fi
    
    # Step 3: Install PyTorch with CUDA support (optimized for RTX 5080/5090)
    header "Step 3: Installing PyTorch with CUDA Support"
    log "Installing PyTorch with CUDA $CUDA_VERSION support for $GPU_TYPE"
    log "Running: pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/$PYTORCH_CUDA"
    pip install --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/$PYTORCH_CUDA
    
    # Step 4: Get platform architecture
    header "Step 4: Detecting Platform Architecture"
    PLATFORM=$(dpkg --print-architecture)
    echo "Platform: $PLATFORM"
    
    # Step 5: Add NVIDIA container toolkit repository
    header "Step 5: Adding NVIDIA Container Toolkit Repository"
    log "Adding NVIDIA GPG key..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    
    log "Adding NVIDIA container toolkit repository..."
    echo "deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/${PLATFORM} /" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    # Step 6: Activate Kamiwaza virtual environment
    header "Step 6: Activating Kamiwaza Virtual Environment"
    log "Running: source /opt/kamiwaza/kamiwaza/venv/bin/activate"
    source /opt/kamiwaza/kamiwaza/venv/bin/activate
    
    # Step 7: Update package lists again
    header "Step 7: Updating Package Lists (After Adding Repository)"
    log "Running: sudo apt update"
    sudo apt update
    
    # Step 8: Install nvidia-container-toolkit
    header "Step 8: Installing nvidia-container-toolkit"
    log "Running: sudo apt install -y nvidia-container-toolkit"
    sudo apt install -y nvidia-container-toolkit
    
    # Step 9: Configure NVIDIA container runtime
    header "Step 9: Configuring NVIDIA Container Runtime"
    log "Running: sudo nvidia-ctk runtime configure --runtime=docker"
    sudo nvidia-ctk runtime configure --runtime=docker
    
    # Step 10: Restart Docker service
    header "Step 10: Restarting Docker Service"
    log "Running: sudo systemctl restart docker"
    sudo systemctl restart docker
    
    # Step 11: Test NVIDIA container runtime
    header "Step 11: Testing NVIDIA Container Runtime"
    log "Running: sudo docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi"
    sudo docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi
    
    # Step 12: Apply GPU-specific optimizations
    header "Step 12: Applying GPU-Specific Optimizations"
    configure_gpu_optimizations
    
    # Step 13: Reserve ports
    header "Step 13: Reserving Ports for Kamiwaza"
    log "Reserving specific ports (comma-separated list or ranges)"
    sudo sysctl -w net.ipv4.ip_local_reserved_ports="8080,8443,9000-9100"
    
    # Step 14: Make port reservation permanent
    header "Step 14: Making Port Reservation Permanent"
    log "Making permanent"
    echo "net.ipv4.ip_local_reserved_ports = 8080,8443,9000-9100" | sudo tee -a /etc/sysctl.conf
    
    # Step 15: Make GPU optimizations permanent
    header "Step 15: Making GPU Optimizations Permanent"
    log "Adding $GPU_TYPE optimizations to /etc/environment"
    
    # Add common environment variables for all GPUs
    echo "CUDA_VISIBLE_DEVICES=0" | sudo tee -a /etc/environment
    echo "TF_FORCE_GPU_ALLOW_GROWTH=true" | sudo tee -a /etc/environment
    echo "TORCH_CUDNN_V8_API_ENABLED=1" | sudo tee -a /etc/environment
    
    # Add GPU-specific memory fraction
    case "$GPU_TYPE" in
        "RTX_5090"|"RTX_4090"|"RTX_3090")
            echo "TF_GPU_MEMORY_FRACTION=0.95" | sudo tee -a /etc/environment
            echo "PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512" | sudo tee -a /etc/environment
            ;;
        "RTX_5080"|"RTX_4080"|"RTX_3080")
            echo "TF_GPU_MEMORY_FRACTION=0.90" | sudo tee -a /etc/environment
            echo "PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:256" | sudo tee -a /etc/environment
            ;;
        "RTX_4070"|"RTX_3070")
            echo "TF_GPU_MEMORY_FRACTION=0.85" | sudo tee -a /etc/environment
            echo "PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128" | sudo tee -a /etc/environment
            ;;
        "RTX_3060")
            echo "TF_GPU_MEMORY_FRACTION=0.80" | sudo tee -a /etc/environment
            echo "PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:64" | sudo tee -a /etc/environment
            ;;
        *)
            echo "TF_GPU_MEMORY_FRACTION=0.75" | sudo tee -a /etc/environment
            echo "PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:64" | sudo tee -a /etc/environment
            ;;
    esac
    
    # Step 15.1: Create udev rules for NVIDIA device access
    header "Step 15.1: Creating udev Rules for NVIDIA Access"
    log "Setting up udev rules to allow all users to access NVIDIA devices..."
    
    # Create udev rules directory if it doesn't exist
    sudo mkdir -p /etc/udev/rules.d
    
    # Create udev rule for NVIDIA devices
    sudo tee /etc/udev/rules.d/99-nvidia.rules > /dev/null << 'EOF'
# NVIDIA GPU access for all users
SUBSYSTEM=="nvidia", MODE="0666"
SUBSYSTEM=="nvidia_uvm", MODE="0666"
SUBSYSTEM=="nvidia_uvm_tools", MODE="0666"
SUBSYSTEM=="nvidia_modeset", MODE="0666"
SUBSYSTEM=="nvidia_drm", MODE="0666"

# NVIDIA device nodes
KERNEL=="nvidia*", MODE="0666"
KERNEL=="nvidia_uvm*", MODE="0666"
KERNEL=="nvidia_modeset*", MODE="0666"
KERNEL=="nvidia_drm*", MODE="0666"

# CUDA device access
KERNEL=="nvidiactl", MODE="0666"
KERNEL=="nvidia-uvm", MODE="0666"
KERNEL=="nvidia-uvm-tools", MODE="0666"
EOF
    
    log "Created udev rules for NVIDIA device access"
    
    # Reload udev rules
    if command -v udevadm >/dev/null 2>&1; then
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        log "Reloaded udev rules"
    fi
    
    # Create nvidia group and add users if it doesn't exist
    if ! getent group nvidia >/dev/null 2>&1; then
        sudo groupadd nvidia
        log "Created nvidia group"
    fi
    
    # Add current user to nvidia group
    CURRENT_USER=$(whoami)
    if [ "$CURRENT_USER" != "root" ]; then
        sudo usermod -a -G nvidia "$CURRENT_USER"
        log "Added user $CURRENT_USER to nvidia group"
    fi
    
    # Add kamiwaza user to nvidia group if different from current user
    if [ "$CURRENT_USER" != "kamiwaza" ]; then
        sudo usermod -a -G nvidia kamiwaza
        log "Added kamiwaza user to nvidia group"
    fi
    
    # Final instructions
    header "Installation Complete!"
    echo
    success "NVIDIA GPU support has been set up successfully for $GPU_TYPE!"
    echo
    warn "IMPORTANT: GPU acceleration may require a FULL SYSTEM REBOOT!"
    echo
    warn "NOTE: Group membership changes require logging out and back in to take effect."
    echo
    
    # Request system reboot
    request_reboot
    
    echo
    log "Next Steps:"
    echo "  1. Verify NVIDIA drivers: 'nvidia-smi' (now accessible to all users)"
    echo "  2. Test PyTorch CUDA: 'python -c \"import torch; print(torch.cuda.is_available())\"'" 
    echo "  3. If GPU not detected, ensure WSL2 GPU passthrough is enabled"
    echo "  4. Verify Python 3.12: 'python3 --version'"
    echo "  5. Test nvidia-smi as regular user: 'nvidia-smi' (no sudo needed)"
    echo "  6. If needed, use wrapper: 'nvidia-smi-wrapper'"
    echo
    # Display GPU-specific features
    case "$GPU_TYPE" in
        "RTX_5090"|"RTX_4090"|"RTX_3090")
            log "High-End GPU Features (24GB VRAM):"
            echo "  - 24GB VRAM optimized for large models"
            echo "  - Enhanced 8K gaming support"
            echo "  - Improved AI/ML performance"
            echo "  - Advanced memory management"
            echo
            ;;
        "RTX_5080"|"RTX_4080"|"RTX_3080")
            log "Mid-High GPU Features (16GB/10GB VRAM):"
            echo "  - High-performance gaming and AI workloads"
            echo "  - Optimized memory management"
            echo "  - Balanced performance settings"
            echo
            ;;
        "RTX_4070"|"RTX_3070")
            log "Mid-Range GPU Features (12GB/8GB VRAM):"
            echo "  - Balanced performance for gaming and AI"
            echo "  - Efficient memory utilization"
            echo "  - Cost-effective performance"
            echo
            ;;
        "RTX_3060")
            log "Entry-Level GPU Features (12GB VRAM):"
            echo "  - Good performance for entry-level workloads"
            echo "  - Efficient memory management"
            echo "  - Budget-friendly optimization"
            echo
            ;;
    esac
    log "Troubleshooting:"
    echo "  - Check WSL2 GPU support: 'nvidia-smi'"
    echo "  - Verify PyTorch CUDA: 'python -c \"import torch; print(torch.cuda.device_count())\"'"
    echo "  - Ensure Windows NVIDIA drivers are up to date"
    echo "  - Verify Python version: python3 --version"
    echo
    read -p "Press Enter to finish installation..."
    
    echo
    success "Setup completed successfully for $GPU_TYPE! [SUCCESS]"
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

# Run main function
main "$@" 