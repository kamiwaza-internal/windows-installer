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

    $nvidiaRTX = $gpus | Where-Object { $_.Name -match "NVIDIA GeForce RTX (50|60|70|80|90)[0-9]*" }
    $intelArc = $gpus | Where-Object { $_.Name -like "*Intel(R) Arc(TM)*" }

    if ($nvidiaRTX) {
        Write-LogMessage "NVIDIA GeForce RTX GPU detected!" "INFO"
        Write-LogMessage "Setting up NVIDIA GPU acceleration in WSL..."

        $nvidiaScriptLines = @(
            "#!/bin/bash",
            "# NVIDIA GPU Setup Script for WSL2",
            "",
            'echo "Setting up NVIDIA GPU support..."',
            "",
            "# Check if nvidia-smi is available",
            "if which nvidia-smi > /dev/null 2>&1; then",
            '    echo "NVIDIA drivers detected in WSL"',
            "    nvidia-smi",
            "else",
            '    echo "NVIDIA drivers not detected. Please ensure:"',
            '    echo "1. You have installed NVIDIA GPU drivers on Windows"',
            '    echo "2. You are using WSL2 not WSL1"',
            '    echo "3. Your Windows version supports GPU passthrough"',
            "fi",
            "",
            "# Set environment variables for CUDA",
            "echo 'export CUDA_HOME=/usr/local/cuda' >> ~/.bashrc",
            'echo "export PATH=\$PATH:\$CUDA_HOME/bin" >> ~/.bashrc',
            'echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$CUDA_HOME/lib64" >> ~/.bashrc',
            "",
            'echo "NVIDIA GPU setup completed!"'
        )

        try {
            # Create temporary file with Unix line endings
            $nvidiaScriptLines | Out-File -FilePath "setup_nvidia_gpu.sh" -Encoding UTF8
            
            # Copy to WSL and fix line endings
            $currentDir = (Get-Location).Path
            $wslPath = "/mnt/" + $currentDir.Replace(":", "").Replace("\", "/").ToLower()
            wsl -d $WSLDistribution -- cp "$wslPath/setup_nvidia_gpu.sh" /tmp/setup_nvidia_gpu.sh
            wsl -d $WSLDistribution -- bash -c "dos2unix /tmp/setup_nvidia_gpu.sh 2>/dev/null || sed -i 's/\r$//' /tmp/setup_nvidia_gpu.sh"
            wsl -d $WSLDistribution -- sudo mv /tmp/setup_nvidia_gpu.sh /usr/local/bin/setup_nvidia_gpu.sh
            wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/setup_nvidia_gpu.sh
            
            Write-LogMessage "Created NVIDIA GPU setup script in WSL: /usr/local/bin/setup_nvidia_gpu.sh"

            Write-LogMessage "Executing NVIDIA GPU setup..."
            wsl -d $WSLDistribution -- bash /usr/local/bin/setup_nvidia_gpu.sh
            
            # Clean up temp file after successful copy
            Remove-Item "setup_nvidia_gpu.sh" -ErrorAction SilentlyContinue
        } catch {
            Write-LogMessage "Failed to create NVIDIA GPU script: $($_.Exception.Message)" "ERROR"
        }
    }

    if ($intelArc) {
        Write-LogMessage "Intel Arc GPU detected!" "INFO"
        Write-LogMessage "Setting up Intel Arc GPU acceleration in WSL..."

        $intelScriptLines = @(
            "#!/bin/bash",
            "# Intel Arc GPU Setup Script for WSL2",
            "",
            'echo "Setting up Intel Arc GPU support..."',
            "",
            "# Check for Intel GPU",
            "if ls /dev/dri/renderD* &> /dev/null; then",
            '    echo "Intel GPU device nodes detected"',
            "    ls -la /dev/dri/",
            "else",
            '    echo "Intel GPU device nodes not found. Please ensure:"',
            '    echo "1. You have installed Intel Arc GPU drivers on Windows"',
            '    echo "2. You are using WSL2 with GPU support"',
            "fi",
            "",
            "# Install Intel GPU tools if not present",
            "if ! which intel_gpu_top > /dev/null 2>&1; then",
            '    echo "Installing Intel GPU tools..."',
            "    sudo apt-get update",
            "    sudo apt-get install -y intel-gpu-tools",
            "fi",
            "",
            "# Set permissions for GPU access",
            "sudo chmod 666 /dev/dri/renderD* 2>/dev/null || true",
            "",
            "# Set environment variables for Intel GPU",
            "echo 'export LIBVA_DRIVER_NAME=iHD' >> ~/.bashrc",
            "echo 'export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri' >> ~/.bashrc",
            "",
            'echo "Intel Arc GPU setup completed!"'
        )

        try {
            # Create temporary file with Unix line endings
            $intelScriptLines | Out-File -FilePath "setup_intel_gpu.sh" -Encoding UTF8
            
            # Copy to WSL and fix line endings
            $currentDir = (Get-Location).Path
            $wslPath = "/mnt/" + $currentDir.Replace(":", "").Replace("\", "/").ToLower()
            wsl -d $WSLDistribution -- cp "$wslPath/setup_intel_gpu.sh" /tmp/setup_intel_gpu.sh
            wsl -d $WSLDistribution -- bash -c "dos2unix /tmp/setup_intel_gpu.sh 2>/dev/null || sed -i 's/\r$//' /tmp/setup_intel_gpu.sh"
            wsl -d $WSLDistribution -- sudo mv /tmp/setup_intel_gpu.sh /usr/local/bin/setup_intel_gpu.sh
            wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/setup_intel_gpu.sh
            
            Write-LogMessage "Created Intel Arc GPU setup script in WSL: /usr/local/bin/setup_intel_gpu.sh"

            Write-LogMessage "Executing Intel Arc GPU setup..."
            wsl -d $WSLDistribution -- bash /usr/local/bin/setup_intel_gpu.sh
            
            # Clean up temp file after successful copy
            Remove-Item "setup_intel_gpu.sh" -ErrorAction SilentlyContinue
        } catch {
            Write-LogMessage "Failed to create Intel Arc GPU script: $($_.Exception.Message)" "ERROR"
        }
    }

    if (-not $nvidiaRTX -and -not $intelArc) {
        Write-LogMessage "No supported GPU acceleration hardware detected" "WARN"
    }

    # Create a GPU status check script
    $statusScriptLines = @(
        "#!/bin/bash",
        "# Kamiwaza GPU Status Check Script",
        "",
        'echo "=== Kamiwaza GPU Status ==="',
        'echo ""',
        "",
        "# Check for NVIDIA GPU",
        "if which nvidia-smi > /dev/null 2>&1; then",
        '    echo "NVIDIA GPU Status:"',
        "    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader",
        '    echo ""',
        "fi",
        "",
        "# Check for Intel GPU",
        "if ls /dev/dri/renderD* &> /dev/null; then",
        '    echo "Intel GPU Status:"',
        "    ls -la /dev/dri/",
        "    if which intel_gpu_top > /dev/null 2>&1; then",
        '        echo "Intel GPU tools installed"',
        "    fi",
        '    echo ""',
        "fi",
        "",
        "# Check OpenGL support",
        "if which glxinfo > /dev/null 2>&1; then",
        '    echo "OpenGL Renderer:"',
        "    glxinfo | grep 'OpenGL renderer string'",
        "fi"
    )

    try {
        # Create temporary file with Unix line endings
        $statusScriptLines | Out-File -FilePath "kamiwaza_gpu_status.sh" -Encoding UTF8
        
        # Copy to WSL and fix line endings
        $currentDir = (Get-Location).Path
        $wslPath = "/mnt/" + $currentDir.Replace(":", "").Replace("\", "/").ToLower()
        wsl -d $WSLDistribution -- cp "$wslPath/kamiwaza_gpu_status.sh" /tmp/kamiwaza_gpu_status.sh
        wsl -d $WSLDistribution -- bash -c "dos2unix /tmp/kamiwaza_gpu_status.sh 2>/dev/null || sed -i 's/\r$//' /tmp/kamiwaza_gpu_status.sh"
        wsl -d $WSLDistribution -- sudo mv /tmp/kamiwaza_gpu_status.sh /usr/local/bin/kamiwaza_gpu_status.sh
        wsl -d $WSLDistribution -- sudo chmod +x /usr/local/bin/kamiwaza_gpu_status.sh
        
        Write-LogMessage "Created GPU status check script: /usr/local/bin/kamiwaza_gpu_status.sh"
        
        # Clean up temp file after successful copy
        Remove-Item "kamiwaza_gpu_status.sh" -ErrorAction SilentlyContinue
    } catch {
        Write-LogMessage "Failed to create GPU status script: $($_.Exception.Message)" "ERROR"
    }

} catch {
    Write-LogMessage "Error during GPU detection: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-LogMessage "GPU detection and configuration completed successfully!"
Write-LogMessage "Check GPU status in WSL with: wsl -d $WSLDistribution -- /usr/local/bin/kamiwaza_gpu_status.sh" 