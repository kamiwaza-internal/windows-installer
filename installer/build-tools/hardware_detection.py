#!/usr/bin/env python3
"""
Hardware Detection Module for Kamiwaza Installer

This module provides hardware detection capabilities to optimize
the installation for specific hardware configurations.

Expandable for future hardware support (AMD, NVIDIA, etc.)
"""

import subprocess
import re
import os
import platform


class HardwareDetector:
    """Detect and configure hardware-specific optimizations"""
    
    def __init__(self, logger=None):
        self.logger = logger or self._default_logger
        self.detected_hardware = {}
        
    def _default_logger(self, message):
        """Default logger if none provided"""
        print(f"[HARDWARE] {message}")
    
    def log(self, message):
        """Log message using provided logger"""
        self.logger(message)
    
    def run_wsl_command(self, wsl_cmd, command, timeout=30):
        """Run command in WSL instance"""
        try:
            full_cmd = wsl_cmd + ['bash', '-c', command]
            result = subprocess.run(
                full_cmd, 
                capture_output=True, 
                text=True, 
                timeout=timeout
            )
            return result.returncode == 0, result.stdout.strip(), result.stderr.strip()
        except subprocess.TimeoutExpired:
            return False, "", "Command timed out"
        except Exception as e:
            return False, "", str(e)
    
    def detect_cpu_vendor(self, wsl_cmd):
        """Detect CPU vendor (Intel, AMD, ARM, etc.)"""
        self.log("Detecting CPU vendor...")
        
        # More comprehensive vendor detection
        vendor_detection_cmd = '''
        if grep -q "GenuineIntel" /proc/cpuinfo; then
            echo "Intel"
        elif grep -q "AuthenticAMD" /proc/cpuinfo; then
            echo "AMD"
        elif grep -q "ARM" /proc/cpuinfo || grep -q "ARM" /proc/device-tree/model 2>/dev/null; then
            echo "ARM"
        elif grep -q "VIA" /proc/cpuinfo; then
            echo "VIA"
        elif grep -q "CentaurHauls" /proc/cpuinfo; then
            echo "Centaur"
        elif grep -q "CyrixInstead" /proc/cpuinfo; then
            echo "Cyrix"
        elif grep -q "TransmetaCPU" /proc/cpuinfo; then
            echo "Transmeta"
        elif grep -q "RiseRiseRise" /proc/cpuinfo; then
            echo "Rise"
        elif grep -q "SiS SiS SiS" /proc/cpuinfo; then
            echo "SiS"
        elif grep -q "UMC UMC UMC" /proc/cpuinfo; then
            echo "UMC"
        elif grep -q "NexGenDriven" /proc/cpuinfo; then
            echo "NexGen"
        else
            # Try to extract vendor from cpuinfo
            vendor=$(grep "^vendor_id" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
            if [ -n "$vendor" ]; then
                echo "$vendor"
            else
                echo "Unknown"
            fi
        fi
        '''
        
        success, output, error = self.run_wsl_command(wsl_cmd, vendor_detection_cmd)
        
        if success:
            cpu_vendor = output.strip()
            self.detected_hardware['cpu_vendor'] = cpu_vendor
            self.log(f"[OK] CPU vendor detected: {cpu_vendor}")
            return cpu_vendor
        else:
            self.log(f"[WARN] Could not detect CPU vendor: {error}")
            return "Unknown"
    
    def detect_cpu_features(self, wsl_cmd):
        """Detect CPU features and capabilities"""
        self.log("Detecting CPU features...")
        
        features = {}
        
        # Check for common CPU features
        feature_checks = {
            'avx': 'grep -q "avx" /proc/cpuinfo',
            'avx2': 'grep -q "avx2" /proc/cpuinfo', 
            'sse4_1': 'grep -q "sse4_1" /proc/cpuinfo',
            'sse4_2': 'grep -q "sse4_2" /proc/cpuinfo',
            'aes': 'grep -q "aes" /proc/cpuinfo'
        }
        
        for feature, check_cmd in feature_checks.items():
            success, _, _ = self.run_wsl_command(wsl_cmd, check_cmd)
            features[feature] = success
            if success:
                self.log(f"[OK] CPU feature detected: {feature}")
        
        self.detected_hardware['cpu_features'] = features
        return features
    
    def detect_gpu_info(self, wsl_cmd):
        """Detect GPU information (primarily for Intel integrated graphics)"""
        self.log("Detecting GPU information...")
        
        # Check for GPU devices in WSL
        success, output, error = self.run_wsl_command(
            wsl_cmd, 
            'ls -la /dev/dri/ 2>/dev/null || echo "No GPU devices found"'
        )
        
        gpu_info = {
            'has_gpu_devices': '/dev/dri' in output if success else False,
            'gpu_devices': output if success else "None detected"
        }
        
        if gpu_info['has_gpu_devices']:
            self.log("[OK] GPU devices detected in WSL")
            self.log(f"  GPU devices: {output}")
        else:
            self.log("[INFO] No GPU devices detected in WSL")
        
        self.detected_hardware['gpu_info'] = gpu_info
        return gpu_info
    
    def should_install_intel_gpu_support(self, wsl_cmd):
        """Determine if Intel GPU OpenCL support should be installed"""
        cpu_vendor = self.detect_cpu_vendor(wsl_cmd)
        gpu_info = self.detect_gpu_info(wsl_cmd)
        
        # Install Intel GPU support if:
        # 1. CPU is Intel (likely has integrated graphics)
        # 2. Running on WSL2 (has GPU passthrough capabilities)  
        # 3. Windows 11 (better WSL GPU support)
        
        should_install = False
        reasons = []
        
        if cpu_vendor == "Intel":
            should_install = True
            reasons.append("Intel CPU detected (likely has integrated graphics)")
        elif cpu_vendor == "AMD":
            reasons.append("AMD CPU detected (consider AMD GPU support instead)")
        elif cpu_vendor == "ARM":
            reasons.append("ARM CPU detected (GPU support varies by implementation)")
        else:
            reasons.append(f"{cpu_vendor} CPU detected (GPU support unknown)")
        
        # Check WSL version
        success, wsl_version, _ = self.run_wsl_command(
            wsl_cmd, 
            'uname -r | grep -q "WSL2" && echo "WSL2" || echo "WSL1"'
        )
        
        if success and "WSL2" in wsl_version:
            reasons.append("WSL2 detected (supports GPU passthrough)")
        else:
            should_install = False
            reasons.append("WSL2 not detected (GPU support limited)")
        
        # Check Windows version (optional - don't fail if we can't detect)
        try:
            windows_version = platform.release()
            if windows_version in ["10", "11"]:
                reasons.append(f"Windows {windows_version} detected")
            else:
                reasons.append(f"Windows {windows_version} detected (compatibility unknown)")
        except:
            reasons.append("Windows version detection failed")
        
        self.detected_hardware['intel_gpu_recommended'] = should_install
        self.detected_hardware['intel_gpu_reasons'] = reasons
        
        if should_install:
            self.log("[OK] Intel GPU OpenCL support recommended")
            for reason in reasons:
                self.log(f"  • {reason}")
        else:
            self.log("[INFO] Intel GPU OpenCL support not recommended")
            for reason in reasons:
                self.log(f"  • {reason}")
        
        return should_install
    
    def get_intel_opencl_install_commands(self):
        """Get commands for Intel OpenCL installation"""
        return [
            # Remove conflicting packages
            "sudo apt-get purge -y intel-opencl-icd intel-level-zero-gpu level-zero",
            "sudo apt-get autoremove -y",
            "sudo apt-get clean",
            
            # Install OpenCL loader and tools
            "sudo apt-get update",
            "sudo apt-get install -y ocl-icd-libopencl1 ocl-icd-opencl-dev opencl-headers clinfo",
            
            # Add Intel oneAPI repository
            "wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null",
            'echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list',
            
            # Install Intel OpenCL runtime
            "sudo apt-get update",
            "sudo apt-get install -y intel-oneapi-runtime-opencl",
            
            # Add Intel Graphics PPA (optional but recommended)
            "sudo apt-get install -y software-properties-common",
            "sudo add-apt-repository -y ppa:kobuk-team/intel-graphics",
            "sudo apt-get update", 
            "sudo apt-get install -y intel-media-va-driver-non-free libmfx-gen1 libvpl2 libvpl-tools libva-glx2 va-driver-all vainfo",
            
            # Configure permissions
            "sudo usermod -a -G render $USER"
        ]
    
    def get_intel_opencl_verification_commands(self):
        """Get commands to verify Intel OpenCL installation"""
        return [
            "clinfo",  # Should show Intel OpenCL platform
            "clinfo | grep -i intel || echo 'No Intel OpenCL platform found'"
        ]
    
    def get_amd_gpu_support_commands(self):
        """Get commands for AMD GPU support installation"""
        return [
            # Remove conflicting packages
            "sudo apt-get purge -y intel-opencl-icd intel-level-zero-gpu level-zero",
            "sudo apt-get autoremove -y",
            "sudo apt-get clean",
            
            # Install OpenCL loader and tools
            "sudo apt-get update",
            "sudo apt-get install -y ocl-icd-libopencl1 ocl-icd-opencl-dev opencl-headers clinfo",
            
            # Add AMD ROCm repository (for newer AMD GPUs)
            "wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | sudo apt-key add -",
            'echo "deb [arch=amd64] https://repo.radeon.com/rocm/apt/debian ubuntu main" | sudo tee /etc/apt/sources.list.d/rocm.list',
            
            # Install AMD OpenCL runtime
            "sudo apt-get update",
            "sudo apt-get install -y rocm-opencl-runtime",
            
            # Install Mesa drivers for older AMD GPUs
            "sudo apt-get install -y mesa-opencl-icd",
            
            # Configure permissions
            "sudo usermod -a -G render $USER"
        ]
    
    def get_arm_gpu_support_commands(self):
        """Get commands for ARM GPU support installation"""
        return [
            # Install OpenCL loader and tools
            "sudo apt-get update",
            "sudo apt-get install -y ocl-icd-libopencl1 ocl-icd-opencl-dev opencl-headers clinfo",
            
            # Install Mesa drivers (common for ARM Mali GPUs)
            "sudo apt-get install -y mesa-opencl-icd",
            
            # Install ARM Mali drivers if available
            "sudo apt-get install -y mali-g610-firmware || echo 'Mali firmware not available'",
            
            # Configure permissions
            "sudo usermod -a -G render $USER"
        ]
    
    def get_vendor_specific_optimizations(self, wsl_cmd):
        """Get vendor-specific optimization commands"""
        cpu_vendor = self.detect_cpu_vendor(wsl_cmd)
        
        if cpu_vendor == "Intel":
            return {
                'description': 'Intel CPU optimizations',
                'commands': [
                    # Intel-specific optimizations
                    'echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor',
                    'echo 0 | sudo tee /proc/sys/kernel/nmi_watchdog',
                    'echo 1 | sudo tee /proc/sys/kernel/sched_rt_runtime_us'
                ]
            }
        elif cpu_vendor == "AMD":
            return {
                'description': 'AMD CPU optimizations',
                'commands': [
                    # AMD-specific optimizations
                    'echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor',
                    'echo 0 | sudo tee /proc/sys/kernel/nmi_watchdog',
                    'echo 1 | sudo tee /proc/sys/kernel/sched_rt_runtime_us'
                ]
            }
        elif cpu_vendor == "ARM":
            return {
                'description': 'ARM CPU optimizations',
                'commands': [
                    # ARM-specific optimizations
                    'echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || echo "CPU governor not available"',
                    'echo 1 | sudo tee /proc/sys/kernel/sched_rt_runtime_us'
                ]
            }
        else:
            return {
                'description': f'Generic optimizations for {cpu_vendor}',
                'commands': [
                    # Generic optimizations
                    'echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || echo "CPU governor not available"',
                    'echo 1 | sudo tee /proc/sys/kernel/sched_rt_runtime_us'
                ]
            }
    
    def install_intel_gpu_support(self, wsl_cmd, run_command_func):
        """Install Intel GPU OpenCL support"""
        self.log("Installing Intel GPU OpenCL support...")
        
        install_commands = self.get_intel_opencl_install_commands()
        
        for i, cmd in enumerate(install_commands, 1):
            self.log(f"[{i}/{len(install_commands)}] Running: {cmd}")
            
            # Use longer timeout for package operations
            timeout = 300 if any(pkg_cmd in cmd for pkg_cmd in ['apt-get', 'add-apt-repository']) else 60
            
            ret, out, err = run_command_func(wsl_cmd + ['bash', '-c', cmd], timeout=timeout)
            
            if ret != 0:
                self.log(f"[WARN] Warning: Command failed (continuing): {cmd}")
                if err:
                    self.log(f"  Error: {err}")
            else:
                self.log(f"[OK] Command completed successfully")
        
        # Verify installation
        self.log("Verifying Intel OpenCL installation...")
        verify_commands = self.get_intel_opencl_verification_commands()
        
        for cmd in verify_commands:
            ret, out, err = run_command_func(wsl_cmd + ['bash', '-c', cmd], timeout=30)
            if ret == 0 and out:
                self.log(f"[OK] Verification: {out}")
            else:
                self.log(f"[INFO] Verification output: {err if err else 'No output'}")
    
    def detect_and_configure_hardware(self, wsl_cmd, run_command_func):
        """Main method to detect hardware and configure optimizations"""
        self.log("=== HARDWARE DETECTION AND CONFIGURATION ===")
        
        # Detect CPU
        cpu_vendor = self.detect_cpu_vendor(wsl_cmd)
        cpu_features = self.detect_cpu_features(wsl_cmd)
        
        # Detect GPU
        gpu_info = self.detect_gpu_info(wsl_cmd)
        
        # Configure vendor-specific optimizations
        if cpu_vendor == "Intel":
            should_install_gpu = self.should_install_intel_gpu_support(wsl_cmd)
            
            if should_install_gpu:
                try:
                    self.install_intel_gpu_support(wsl_cmd, run_command_func)
                    self.log("[OK] Intel GPU OpenCL support installation completed")
                except Exception as e:
                    self.log(f"[WARN] Warning: Intel GPU support installation failed: {e}")
            else:
                self.log("[INFO] Skipping Intel GPU OpenCL support installation")
        
        elif cpu_vendor == "AMD":
            self.log("[OK] AMD CPU detected - configuring AMD-specific optimizations")
            try:
                # Apply AMD optimizations
                optimizations = self.get_vendor_specific_optimizations(wsl_cmd)
                self.log(f"Applying {optimizations['description']}...")
                
                for cmd in optimizations['commands']:
                    ret, out, err = run_command_func(wsl_cmd + ['bash', '-c', cmd], timeout=30)
                    if ret == 0:
                        self.log(f"[OK] Applied: {cmd}")
                    else:
                        self.log(f"[WARN] Warning: Failed to apply: {cmd}")
                
                # Optionally install AMD GPU support
                self.log("[INFO] AMD GPU support can be installed manually if needed")
                
            except Exception as e:
                self.log(f"[WARN] Warning: AMD optimization configuration failed: {e}")
        
        elif cpu_vendor == "ARM":
            self.log("[OK] ARM CPU detected - configuring ARM-specific optimizations")
            try:
                # Apply ARM optimizations
                optimizations = self.get_vendor_specific_optimizations(wsl_cmd)
                self.log(f"Applying {optimizations['description']}...")
                
                for cmd in optimizations['commands']:
                    ret, out, err = run_command_func(wsl_cmd + ['bash', '-c', cmd], timeout=30)
                    if ret == 0:
                        self.log(f"[OK] Applied: {cmd}")
                    else:
                        self.log(f"[INFO] Note: {cmd} (may not be available on this ARM system)")
                
                # Optionally install ARM GPU support
                self.log("[INFO] ARM GPU support varies by implementation")
                
            except Exception as e:
                self.log(f"[WARN] Warning: ARM optimization configuration failed: {e}")
        
        else:
            self.log(f"[OK] {cpu_vendor} CPU detected - applying generic optimizations")
            try:
                # Apply generic optimizations
                optimizations = self.get_vendor_specific_optimizations(wsl_cmd)
                self.log(f"Applying {optimizations['description']}...")
                
                for cmd in optimizations['commands']:
                    ret, out, err = run_command_func(wsl_cmd + ['bash', '-c', cmd], timeout=30)
                    if ret == 0:
                        self.log(f"[OK] Applied: {cmd}")
                    else:
                        self.log(f"[INFO] Note: {cmd} (may not be available)")
                
            except Exception as e:
                self.log(f"[WARN] Warning: Generic optimization configuration failed: {e}")
        
        self.log("=== HARDWARE CONFIGURATION COMPLETE ===")
        return self.detected_hardware
    
    def detect_gpu_hardware(self):
        """Detect GPU hardware and return detection results for the installer"""
        try:
            import subprocess
            import platform
            
            # Default results
            results = {
                'gpu_acceleration': 'CPU_ONLY',
                'nvidia_rtx_detected': False,
                'intel_arc_detected': False,
                'intel_integrated_detected': False,
                'nvidia_gpu_name': '',
                'intel_gpu_name': ''
            }
            
            # Try to detect GPUs using PowerShell (Windows-specific)
            if platform.system() == "Windows":
                try:
                    # Run PowerShell GPU detection
                    ps_cmd = [
                        'powershell.exe', '-Command',
                        'Get-CimInstance Win32_VideoController | Select-Object Name, AdapterCompatibility | ConvertTo-Json'
                    ]
                    
                    result = subprocess.run(ps_cmd, capture_output=True, text=True, timeout=30)
                    
                    if result.returncode == 0 and result.stdout.strip():
                        import json
                        gpus = json.loads(result.stdout)
                        
                        # Handle single GPU vs multiple GPUs
                        if not isinstance(gpus, list):
                            gpus = [gpus]
                        
                        for gpu in gpus:
                            gpu_name = gpu.get('Name', '').lower()
                            
                            # Check for NVIDIA RTX
                            if 'nvidia' in gpu_name and 'rtx' in gpu_name:
                                results['nvidia_rtx_detected'] = True
                                results['nvidia_gpu_name'] = gpu.get('Name', 'NVIDIA RTX GPU')
                                results['gpu_acceleration'] = 'NVIDIA_RTX'
                                
                            # Check for Intel Arc
                            elif 'intel' in gpu_name and 'arc' in gpu_name:
                                results['intel_arc_detected'] = True
                                results['intel_gpu_name'] = gpu.get('Name', 'Intel Arc GPU')
                                results['gpu_acceleration'] = 'INTEL_ARC'
                                
                            # Check for Intel integrated graphics
                            elif 'intel' in gpu_name and any(x in gpu_name for x in ['uhd', 'iris', 'hd graphics']):
                                results['intel_integrated_detected'] = True
                                results['intel_gpu_name'] = gpu.get('Name', 'Intel Integrated Graphics')
                                if results['gpu_acceleration'] == 'CPU_ONLY':
                                    results['gpu_acceleration'] = 'INTEL_INTEGRATED'
                        
                        # If we found any GPU, update acceleration type
                        if any([results['nvidia_rtx_detected'], results['intel_arc_detected'], results['intel_integrated_detected']):
                            if results['gpu_acceleration'] == 'CPU_ONLY':
                                results['gpu_acceleration'] = 'GPU_ACCELERATED'
                                
                except Exception as e:
                    self.log(f"PowerShell GPU detection failed: {e}")
            
            return results
            
        except Exception as e:
            self.log(f"GPU detection failed: {e}")
            # Return default CPU-only results
            return {
                'gpu_acceleration': 'CPU_ONLY',
                'nvidia_rtx_detected': False,
                'intel_arc_detected': False,
                'intel_integrated_detected': False,
                'nvidia_gpu_name': '',
                'intel_gpu_name': ''
            }


# Example usage for testing
if __name__ == "__main__":
    detector = HardwareDetector()
    print("Hardware detector initialized")
    print("Available methods:")
    print("- detect_cpu_vendor(wsl_cmd) - Supports Intel, AMD, ARM, VIA, Centaur, etc.")
    print("- detect_cpu_features(wsl_cmd)")  
    print("- detect_gpu_info(wsl_cmd)")
    print("- should_install_intel_gpu_support(wsl_cmd)")
    print("- install_intel_gpu_support(wsl_cmd, run_command_func)")
    print("- get_amd_gpu_support_commands()")
    print("- get_arm_gpu_support_commands()")
    print("- get_vendor_specific_optimizations(wsl_cmd)")
    print("- detect_and_configure_hardware(wsl_cmd, run_command_func)")
    print("- detect_gpu_hardware() - NEW: Detects GPU hardware for installer")
    
    # Test GPU detection
    print("\nTesting GPU detection...")
    gpu_results = detector.detect_gpu_hardware()
    print(f"GPU detection results: {gpu_results}")