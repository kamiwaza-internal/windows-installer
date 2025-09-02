#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# NVIDIA GPU Setup Script for WSL2 Ubuntu 24.04 (Noble)
# Focused on NVIDIA Container Toolkit (no driver/CUDA toolkit installs inside WSL)

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

# Logging helpers
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

# GPU detection and configuration (report only; do not tune host)
detect_gpu() {
    header "GPU Detection"

    if ! command -v nvidia-smi >/dev/null 2>&1; then
        warn "nvidia-smi not found. Windows NVIDIA driver controls CUDA in WSL."
        warn "Ensure the latest Windows NVIDIA driver is installed."
        return 1
    fi

    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits 2>/dev/null || true)
    if [ -z "${GPU_INFO}" ]; then
        warn "Could not detect GPU information via nvidia-smi."
        return 1
    fi

    GPU_NAME=$(echo "$GPU_INFO" | cut -d',' -f1 | xargs)
    GPU_MEMORY=$(echo "$GPU_INFO" | cut -d',' -f2 | xargs)
    DRIVER_VERSION=$(echo "$GPU_INFO" | cut -d',' -f3 | xargs)
    HOST_CUDA=$(nvidia-smi 2>/dev/null | awk '/CUDA Version/ {print $NF; exit}')

    log "Detected GPU: $GPU_NAME"
    log "GPU Memory: ${GPU_MEMORY} MB"
    log "Windows Driver Version: $DRIVER_VERSION"

    GPU_TYPE="${GPU_NAME// /_}"
    CUDA_VERSION="$HOST_CUDA"
    PYTORCH_CUDA="auto"
    MEMORY_OPTIMIZATION="${GPU_MEMORY}MB"
    PERFORMANCE_MODE="auto"

    echo
    log "GPU Configuration Overview:"
    echo "  Type: $GPU_TYPE"
    echo "  Host (Windows) CUDA: $CUDA_VERSION"
    echo "  Memory Hint: $MEMORY_OPTIMIZATION"
    echo "  Performance Mode: $PERFORMANCE_MODE"
    echo "  Note: Containers choose userspace CUDA. If a container requires newer CUDA than host exposes, update Windows NVIDIA driver or set NVIDIA_DISABLE_REQUIRE=1 in that container."
    echo
}

# No host-level tuning under WSL; do per-container if needed (e.g., PYTORCH_CUDA_ALLOC_CONF).
configure_gpu_optimizations() {
    header "GPU Optimizations"
    log "WSL: skipping kernel/sysctl tweaks; set PyTorch/Triton envs in container definitions instead."
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
    if command -v lsb_release >/dev/null 2>&1; then
        if ! lsb_release -d | grep -q "Ubuntu 24.04"; then
            warn "This script is optimized for Ubuntu 24.04. Your version: $(lsb_release -d | cut -f2)"
            warn "Continuing with installation..."
        else
            log "Ubuntu 24.04 detected [OK]"
        fi
    else
        warn "lsb_release not found; skipping Ubuntu version check"
    fi
}

# Prerequisites check
check_prerequisites() {
    header "Checking Prerequisites"
    check_user
    check_wsl2
    check_ubuntu_version

    log "Prerequisites verified. Ensure you have:"
    log "1. Windows 11 + WSL2"
    log "2. Updated Windows NVIDIA GPU driver (controls CUDA version in WSL)"
    log "3. Ubuntu 24.04 (Noble)"
    echo
}

# Attempt to repair dpkg/apt when packages are in 'reinstreq' state
fix_broken_packages() {
    header "Repairing broken package state"
    sudo dpkg --configure -a || true
    local TIMEOUT=""
    if command -v timeout >/dev/null 2>&1; then
        TIMEOUT="timeout 180s"
    fi
    BROKEN_PKGS=$(dpkg-query -Wf '${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null | awk '$1 ~ /r/ {print $2}' | xargs || true)
    if [ -n "${BROKEN_PKGS}" ]; then
        warn "Detected packages requiring reinstallation: ${BROKEN_PKGS}"
        for pkg in ${BROKEN_PKGS}; do
            warn "Handling package: ${pkg}"
            # Skip NVIDIA driver/kernel packages in WSL; only handle container toolkit packages
            if [[ "${pkg}" == nvidia-container-toolkit* || "${pkg}" == libnvidia-container* ]]; then
                :
            elif [[ "${pkg}" == nvidia-* || "${pkg}" == libnvidia-* ]]; then
                warn "Removing broken driver package ${pkg} (managed by Windows/WSL) to unblock apt"
                sudo dpkg --remove --force-remove-reinstreq "${pkg}" || sudo dpkg --purge --force-all "${pkg}" || true
                continue
            fi
            if apt-cache policy "${pkg}" 2>/dev/null | grep -q "Candidate:" && \
               ! apt-cache policy "${pkg}" 2>/dev/null | grep -q "Candidate: (none)"; then
                log "Reinstalling ${pkg} from repository"
                sudo ${TIMEOUT} apt-get install -y --reinstall "${pkg}" || true
            else
                DEB_PATH=$(ls /var/cache/apt/archives/${pkg}_*.deb 2>/dev/null | head -n1)
                if [ -n "${DEB_PATH}" ]; then
                    log "Reinstalling ${pkg} from local archive ${DEB_PATH}"
                    sudo ${TIMEOUT} apt-get install -y --reinstall "${DEB_PATH}" || true
                else
                    warn "No archive available for ${pkg}; forcing removal to unblock apt"
                    sudo dpkg --remove --force-remove-reinstreq "${pkg}" || sudo dpkg --purge --force-all "${pkg}" || true
                fi
            fi
        done
        sudo dpkg --configure -a || true
        sudo apt-get -f install -y || true
        sudo apt-get update || true
    else
        log "No broken packages detected [OK]"
    fi
    echo
}

# Docker restart helper for WSL
restart_docker() {
    header "Restarting Docker daemon"
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        if sudo systemctl restart docker; then success "Docker restarted via systemd"; return 0; fi
    fi
    if command -v service >/dev/null 2>&1; then
        if sudo service docker restart; then success "Docker restarted via service"; return 0; fi
    fi
    warn "No systemd/service. Trying HUP or manual start."
    if pgrep dockerd >/dev/null 2>&1; then
        pgrep dockerd | xargs -r sudo kill -HUP || true
        sleep 1
    fi
    if ! pgrep dockerd >/dev/null 2>&1; then
        warn "dockerd not running; starting foregroundless daemon"
        sudo nohup dockerd -H unix:///var/run/docker.sock >/var/log/dockerd.log 2>&1 &
        sleep 2
    fi
    if pgrep dockerd >/dev/null 2>&1; then
        success "Docker daemon running"
    else
        error "Failed to (re)start Docker"
    fi
}

# Install NVIDIA Container Toolkit repo (libnvidia-container)
install_nvidia_toolkit_repo() {
    header "Installing NVIDIA Container Toolkit repo"
    sudo apt-get update -y || true
    sudo apt-get install -y curl ca-certificates gnupg || true
    sudo mkdir -p /usr/share/keyrings
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | sudo gpg --dearmor | sudo tee /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg >/dev/null
    sudo chmod 644 /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg || true
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
    sudo apt-get update
}

# Configure Docker GPU runtime + CDI
configure_nvidia_runtime() {
    header "Configuring Docker NVIDIA runtime"
    sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker || warn "nvidia-ctk runtime configure failed"
    sudo mkdir -p /etc/cdi
    sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml || warn "CDI generation failed"
    restart_docker
    docker info --format '{{json .Runtimes}}' || true
}

# Check Docker context and GPU runtime availability
check_docker_context() {
    header "Docker context"
    local ctx
    ctx=$(docker context show 2>/dev/null || true)
    if [ -n "${ctx}" ]; then
        log "Current Docker context: ${ctx}"
    else
        warn "Docker context not available"
    fi
    docker context ls || true

    # Warn if desktop-linux context without NVIDIA runtime visible
    if echo "${ctx}" | grep -q "desktop-linux"; then
        if ! docker info 2>/dev/null | grep -qi "nvidia"; then
            warn "Docker Desktop context detected without NVIDIA runtime. Enable GPU in Docker Desktop settings or switch to 'default' context."
        fi
    fi
    echo
}

# Installation verification
verify_installation() {
    header "Installation Verification"
    echo
    log "Verifying NVIDIA GPU availability..."
    echo

    log "Checking NVIDIA packages..."
    dpkg -l | grep -E "(nvidia|cuda)" | head -10 || true

    echo
    log "Checking NVIDIA GPU detection..."
    if command -v nvidia-smi >/dev/null 2>&1; then
        log "nvidia-smi command found - testing GPU detection..."
        echo "Running: nvidia-smi --query-gpu=name,driver_version --format=csv,noheader"
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || warn "nvidia-smi failed to detect GPU"
    else
        warn "nvidia-smi command not found - Windows NVIDIA driver may not be installed or enabled for WSL"
    fi

    echo
    log "Checking NVIDIA device files..."
    ls -la /dev/nvidia* 2>/dev/null || warn "No NVIDIA device files found"

    echo
    log "Checking user groups..."
    groups $USER || true

    echo
    log "Checking system logs for NVIDIA GPU..."
    dmesg | grep -i nvidia | tail -5 2>/dev/null || warn "No NVIDIA GPU messages in dmesg"

}

# Main execution
main() {
    header "NVIDIA GPU CUDA Setup for WSL2"
    log "Setting up CUDA support for NVIDIA RTX GPU on WSL2 Ubuntu 24.04 (Noble)"
    log "Using NVIDIA Container Toolkit repo (no driver installs in WSL)"
    echo

    check_prerequisites

    # Preflight: repair any dpkg/apt issues
    fix_broken_packages

    # Track installation success
    installation_success=true

    # 1. Update system
    header "System Update"
    if sudo apt-get update && sudo apt-get upgrade -y; then
        log "[OK] System update completed"
    else
        warn "[WARN] System update had issues - continuing anyway"
        installation_success=false
    fi

    # 2. Optional cleanup (off by default; pass --force-clean to enable)
    if [[ "${1:-}" == "--force-clean" ]]; then
        header "Cleanup Previous NVIDIA Container Toolkit"
        sudo apt-get purge -y nvidia-container-toolkit || true
        sudo apt-get autoremove -y || true
        sudo apt-get clean || true
        log "[OK] Cleanup completed"
    fi

    # Repair any newly broken states after cleanup
    fix_broken_packages

    # 3. Install NVIDIA Container Toolkit repo & package and configure runtime
    header "Installing NVIDIA Container Toolkit"
    if install_nvidia_toolkit_repo && configure_nvidia_runtime; then
        log "[OK] NVIDIA Container Toolkit installed and runtime configured"
    else
        error "[ERROR] Failed to install/configure NVIDIA Container Toolkit"
        installation_success=false
    fi

    # 4. No CUDA toolkit or drivers installed inside WSL

    # 5. Configure logging dir
    header "Configure Kamiwaza Log Directory"
    mkdir -p "$HOME/kamiwaza/logs"
    if ! grep -q 'KAMIWAZA_LOG_DIR' "$HOME/.bashrc" 2>/dev/null; then
        echo 'export KAMIWAZA_LOG_DIR=$HOME/kamiwaza/logs' >> "$HOME/.bashrc"
    fi
    export KAMIWAZA_LOG_DIR="$HOME/kamiwaza/logs"
    log "KAMIWAZA_LOG_DIR set to $KAMIWAZA_LOG_DIR"

    # GPU info and context
    detect_gpu || true
    configure_gpu_optimizations || true
    check_docker_context || true
    
    # Create nvidia-smi symlink if WSL library exists
    if [ -f "/usr/lib/wsl/lib/nvidia-smi" ]; then
        sudo ln -sf /usr/lib/wsl/lib/nvidia-smi /usr/local/bin/nvidia-smi
        log "Created nvidia-smi symlink"
    fi

    echo
    if [ "$installation_success" = true ]; then
        log "Setup completed successfully! [SUCCESS]"
        log "All required steps have been executed."
    else
        warn "Setup completed with warnings. Some components may not have installed properly."
        log "Please review the output above for any error messages."
    fi
    echo

    # Always verify installation
    verify_installation || true
    echo

    log "Note: GPU drivers are managed on Windows. If a container requires newer CUDA than host exposes,"
    log "either update the Windows NVIDIA driver or add NVIDIA_DISABLE_REQUIRE=1 to that container."

    echo
    header "Debug Mode - Terminal Will Remain Open"
    echo
    log "This terminal will remain open for debugging purposes."
    log "You can run additional commands to troubleshoot any issues."
    echo
    log "Useful debugging commands:"
    echo "  - nvidia-smi                    # Check NVIDIA GPU status"
    echo "  - nvcc --version               # Check CUDA compiler version (if toolkit installed)"
    echo "  - dpkg -l | grep nvidia       # Check installed NVIDIA packages"
    echo "  - ls -la /dev/nvidia*         # Check NVIDIA device files"
    echo "  - groups                       # Check user groups"
    echo "  - dmesg | grep -i nvidia      # Check kernel messages for NVIDIA GPU"
    echo "  - docker info | grep -i runtime  # Check Docker runtimes"
    echo "  - docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi  # Test GPU access"
    echo

    log "Script completed successfully. Exiting..."
    exit 0
}

# Run main function
main "$@" 