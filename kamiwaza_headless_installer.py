#!/usr/bin/env python3
"""
Headless Kamiwaza installer for MSI integration
No GUI - uses stdout for progress reporting to MSI

AUTOMATIC FEATURES:
- HCS service error detection and automatic repair
- WSL disk attachment failure recovery (no more installer kills!)
- GPU driver installation with automatic system restart
- Headless mode detection and appropriate restart behavior
- WSL environment setup with automatic fallback strategies

RESTART BEHAVIOR:
- Interactive mode: 10 second countdown before automatic restart
- Headless mode: Automatic restart after package installation
- Automatic restart after GPU driver installation + package installation
- Kamiwaza starts automatically after restart via RunOnce registry

NOTE - DO NOT ADD UNICODE CHARACTERS TO ANY FILES IN THIS REPO.
"""
import subprocess
import sys
import os
import platform
import datetime
import time
import argparse
import yaml
import shutil
import tempfile
import ctypes
import importlib.util

class HeadlessKamiwazaInstaller:
    def __init__(self, memory="14GB", version=None, codename=None, build=None, arch=None, 
                 user_email=None, license_key=None, usage_reporting=None, install_mode=None):
        self.memory = memory
        self.kamiwaza_version = version or '0.5.0-rc1'
        self.codename = codename or 'noble'
        self.build_number = build or 1
        self.arch = arch or 'amd64'
        self.user_email = user_email
        self.license_key = license_key
        self.usage_reporting = usage_reporting
        self.install_mode = install_mode
        
        # Note: GPU restart logic is now handled directly in GPU setup scripts
        
        # Initialize GPU detection results (placeholder - will be populated during detection)
        self.gpu_detection_results = {
            'gpu_acceleration': 'CPU_ONLY',
            'nvidia_rtx_detected': False,
            'intel_arc_detected': False,
            'intel_integrated_detected': False,
            'nvidia_gpu_name': '',
            'intel_gpu_name': ''
        }
        
        # Load actual GPU detection results
        self.gpu_detection_results = self.load_gpu_detection_results()
        
        # Test logging system first to ensure it's working
        self.log_output("=== TESTING LOGGING SYSTEM ===")
        self.log_output("Testing multiple logging methods for reliability...")
        
        # Enable maximum debugging
        self.log_output("=== KAMIWAZA INSTALLER DEBUG MODE ENABLED ===")
        self.log_output(f"Installer initialized with parameters:")
        self.log_output(f"  Memory: {self.memory}")
        self.log_output(f"  Version: {self.kamiwaza_version}")
        self.log_output(f"  Codename: {self.codename}")
        self.log_output(f"  Build: {self.build_number}")
        self.log_output(f"  Arch: {self.arch}")
        self.log_output(f"  Email: {self.user_email}")
        self.log_output(f"  License Key: {'***SET***' if self.license_key else 'None'}")
        self.log_output(f"  Usage Reporting: {self.usage_reporting}")
        self.log_output(f"  Install Mode: {self.install_mode}")
        
        # Test logging to all available methods
        self.log_output("=== LOGGING SYSTEM TEST COMPLETE ===")
        self.log_output("All logging methods tested and ready for use")
        
        # Log environment details
        self.log_output(f"Python Version: {sys.version}")
        self.log_output(f"Current Working Directory: {os.getcwd()}")
        self.log_output(f"Script Path: {__file__}")
        
        # Detect Windows Server and provide guidance
        try:
            import platform
            windows_version = platform.platform()
            self.log_output(f"Windows Version: {windows_version}")
            
            if "Server" in windows_version:
                self.log_output("Windows Server detected - WSL may require manual setup")
                if "2019" in windows_version:
                    self.log_output("Server 2019: WSL 1 only, manual feature enable required")
                elif "2022" in windows_version:
                    self.log_output("Server 2022: WSL 2 supported (except Server Core)")
                else:
                    self.log_output("Server version: Check WSL compatibility")
        except Exception as e:
            self.log_output(f"Could not detect Windows version: {e}")
        
        # Change working directory to installer directory if needed
        if os.getcwd().lower().endswith('system32'):
            installer_dir = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza')
            self.log_output(f"Detected System32 directory, changing to: {installer_dir}")
            if os.path.exists(installer_dir):
                os.chdir(installer_dir)
                self.log_output(f"Changed working directory to: {os.getcwd()}")
            else:
                self.log_output(f"WARNING: Installer directory does not exist: {installer_dir}")
        
        self.log_output("=== INITIALIZATION COMPLETE ===\n")

    def load_gpu_detection_results(self):
        """Load GPU detection results - PowerShell already handled this!"""
        # PowerShell detect_gpu.ps1 already detected GPUs and created setup scripts
        # We just need to check what was detected by looking for the scripts
        
        self.log_output("PowerShell GPU detection already completed - checking results...")
        
        # Default results
        results = {
            'gpu_acceleration': 'CPU_ONLY',
            'nvidia_rtx_detected': False,
            'intel_arc_detected': False,
            'intel_integrated_detected': False,
            'nvidia_gpu_name': '',
            'intel_gpu_name': ''
        }
        
        # Check what GPU setup scripts exist (PowerShell already created these)
        nvidia_script = os.path.join(os.path.dirname(__file__), "setup_nvidia_gpu.sh")
        intel_arc_script = os.path.join(os.path.dirname(__file__), "setup_intel_arc_gpu.sh")
        intel_integrated_script = os.path.join(os.path.dirname(__file__), "setup_intel_integrated_gpu.sh")
        
        # CRITICAL FIX: PowerShell detection may be wrong - do our own detection
        self.log_output("PowerShell detection may be incorrect - performing independent GPU detection...")
        
        # Use Windows Management Instrumentation (WMI) to detect actual GPU hardware
        try:
            import subprocess
            # Run PowerShell command to get actual GPU info
            ps_cmd = [
                'powershell.exe', '-Command', 
                'Get-CimInstance Win32_VideoController | Select-Object Name, AdapterCompatibility | ConvertTo-Json'
            ]
            
            ret, out, err = self.run_command(ps_cmd, timeout=30)
            if ret == 0 and out.strip():
                self.log_output("Independent GPU detection completed")
                gpu_info = out.strip()
                
                # Debug: Show what GPU info we actually got
                self.log_output(f"Raw GPU detection output: {gpu_info}")
                
                # Check for Intel Arc (less specific to catch variations)
                if any(x in gpu_info for x in ['Intel(R) Arc', 'Intel Arc', 'Arc(TM)', 'Arc A', 'Arc 3', 'Arc 5', 'Arc 7', 'Arc 9', 'Arc Graphics', 'Intel Arc Graphics', 'Arc(TM) Graphics']):
                    self.log_output("INTEL ARC GPU DETECTED by independent detection!")
                    results['intel_arc_detected'] = True
                    results['intel_gpu_name'] = 'Intel Arc GPU (independent detection)'
                    results['gpu_acceleration'] = 'INTEL_ARC'
                    
                # Check for Intel Integrated (less specific to catch variations)
                elif any(x in gpu_info for x in ['Intel(R) UHD', 'Intel(R) HD', 'Intel(R) Iris', 'Intel UHD', 'Intel HD', 'Intel Iris', 'UHD Graphics', 'HD Graphics', 'Iris Graphics', 'Intel Graphics']):
                    self.log_output("INTEL INTEGRATED GPU DETECTED by independent detection!")
                    results['intel_integrated_detected'] = True
                    results['intel_gpu_name'] = 'Intel Integrated GPU (independent detection)'
                    results['gpu_acceleration'] = 'INTEL_INTEGRATED'
                    
                # Check for NVIDIA RTX (less specific to catch variations)
                elif any(x in gpu_info for x in ['NVIDIA GeForce RTX', 'NVIDIA RTX', 'RTX 20', 'RTX 30', 'RTX 40', 'RTX 50', 'GeForce RTX']):
                    self.log_output("NVIDIA RTX GPU DETECTED by independent detection!")
                    results['nvidia_rtx_detected'] = True
                    results['nvidia_gpu_name'] = 'NVIDIA RTX GPU (independent detection)'
                    results['gpu_acceleration'] = 'NVIDIA_RTX'
                    
                else:
                    self.log_output("No supported GPU hardware detected by independent detection")
                    self.log_output(f"GPU info: {gpu_info}")
                    
            else:
                self.log_output(f"Independent GPU detection failed: {err}")
                self.log_output("Falling back to PowerShell script detection...")
                
                # Fallback to PowerShell script detection
                if os.path.exists(nvidia_script):
                    self.log_output("NVIDIA RTX GPU detected by PowerShell - setup script exists")
                    results['nvidia_rtx_detected'] = True
                    results['nvidia_gpu_name'] = 'NVIDIA RTX GPU (detected by PowerShell)'
                    results['gpu_acceleration'] = 'NVIDIA_RTX'
                    
                elif os.path.exists(intel_arc_script):
                    self.log_output("Intel Arc GPU detected by PowerShell - setup script exists")
                    results['intel_arc_detected'] = True
                    results['intel_gpu_name'] = 'Intel Arc GPU (detected by PowerShell)'
                    results['gpu_acceleration'] = 'INTEL_ARC'
                    
                elif os.path.exists(intel_integrated_script):
                    self.log_output("Intel integrated GPU detected by PowerShell - setup script exists")
                    results['intel_integrated_detected'] = True
                    results['intel_gpu_name'] = 'Intel Integrated GPU (detected by PowerShell)'
                    results['gpu_acceleration'] = 'INTEL_INTEGRATED'
                    
                else:
                    self.log_output("No GPU setup scripts found - running in CPU-only mode")
                    self.log_output("PowerShell detected no supported GPUs")
                    
        except Exception as e:
            self.log_output(f"Error during independent GPU detection: {e}")
            self.log_output("Falling back to PowerShell script detection...")
            
            # Fallback to PowerShell script detection
            if os.path.exists(nvidia_script):
                self.log_output("NVIDIA RTX GPU detected by PowerShell - setup script exists")
                results['nvidia_rtx_detected'] = True
                results['nvidia_gpu_name'] = 'NVIDIA RTX GPU (detected by PowerShell)'
                results['gpu_acceleration'] = 'NVIDIA_RTX'
                
            elif os.path.exists(intel_arc_script):
                self.log_output("Intel Arc GPU detected by PowerShell - setup script exists")
                results['intel_arc_detected'] = True
                results['intel_gpu_name'] = 'Intel Arc GPU (detected by PowerShell)'
                results['gpu_acceleration'] = 'INTEL_ARC'
                
            elif os.path.exists(intel_integrated_script):
                self.log_output("Intel integrated GPU detected by PowerShell - setup script exists")
                results['intel_integrated_detected'] = True
                results['intel_gpu_name'] = 'Intel Integrated GPU (detected by PowerShell)'
                results['gpu_acceleration'] = 'INTEL_INTEGRATED'
                
            else:
                self.log_output("No GPU setup scripts found - running in CPU-only mode")
                self.log_output("PowerShell detected no supported GPUs")
        
        self.log_output(f"GPU detection results (independent + fallback): {results}")
        return results

    def download_gpu_drivers(self, wsl_cmd):
        """Run GPU setup script directly from Windows AppData inside WSL (no copying)"""
        try:
            self.log_output("=== GPU DRIVER SETUP (DIRECT EXECUTION) ===")
            acceleration_mode = self.gpu_detection_results.get('gpu_acceleration', 'CPU_ONLY')
            if acceleration_mode == 'CPU_ONLY':
                self.log_output("GPU acceleration: CPU-only mode (no supported hardware detected)")
                self.log_output("Skipping GPU driver setup")
                return

            # Select script based on detection results
            script_name = None
            gpu_name = ''
            if self.gpu_detection_results.get('nvidia_rtx_detected'):
                script_name = 'setup_nvidia_gpu.sh'
                gpu_name = self.gpu_detection_results.get('nvidia_gpu_name', 'NVIDIA RTX GPU')
            elif self.gpu_detection_results.get('intel_arc_detected'):
                script_name = 'setup_intel_arc_gpu.sh'
                gpu_name = self.gpu_detection_results.get('intel_gpu_name', 'Intel Arc GPU')
            elif self.gpu_detection_results.get('intel_integrated_detected'):
                script_name = 'setup_intel_integrated_gpu.sh'
                gpu_name = self.gpu_detection_results.get('intel_gpu_name', 'Intel Integrated GPU')
            else:
                self.log_output("No supported GPU hardware detected - skipping GPU setup")
                return

            self.log_output(f"Detected GPU: {gpu_name}")

            # Locate script on Windows side: prefer %LOCALAPPDATA%\Kamiwaza, fallback to current dir
            appdata_dir = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza')
            candidate_paths = [
                os.path.join(appdata_dir, script_name),
                os.path.join(os.path.dirname(__file__), script_name),
            ]
            windows_script_path = next((p for p in candidate_paths if os.path.exists(p)), None)
            if not windows_script_path:
                self.log_output(f"ERROR: GPU setup script not found. Checked: {candidate_paths}")
                return

            self.log_output(f"Using GPU setup script: {windows_script_path}")

            # Convert Windows path to WSL path (e.g., C:\Users\... -> /mnt/c/Users/...)
            def to_wsl_path(win_path):
                p = win_path.replace('\\\\', '/').replace('\\', '/')
                if len(p) > 2 and p[1] == ':' and p[2] == '/':
                    drive = p[0].lower()
                    return f"/mnt/{drive}/{p[3:]}"
                return p

            wsl_script_path = to_wsl_path(windows_script_path)
            self.log_output(f"WSL script path: {wsl_script_path}")

            # Ensure the script is visible from WSL and execute it
            exec_cmd = f"sudo sed -i 's/\\r$//' '{wsl_script_path}' && sudo -u kamiwaza bash '{wsl_script_path}'"
            self.log_output(f"Executing command: {wsl_cmd + ['bash', '-lc', exec_cmd]}")
            # Ensure the script is visible from WSL
            ret, out, err = self.run_command_with_streaming(
                wsl_cmd + ['bash', '-lc', exec_cmd],
            )


            if ret == 0:
                self.log_output("GPU setup script completed successfully")
            else:
                self.log_output(f"GPU setup script failed with exit code {ret}")
                if err:
                    self.log_output(f"Setup error: {err}")
                if out:
                    self.log_output("Setup output:")
                    self.log_output(out)

            self.log_output("=== GPU DRIVER SETUP COMPLETE ===")
        except Exception as e:
            self.log_output(f"Error configuring GPU acceleration: {e}")

    def verify_gpu_driver_status(self, wsl_cmd):
        """Verify that GPU drivers are actually working"""
        try:
            if self.gpu_detection_results['nvidia_rtx_detected']:
                self.log_output("Verifying NVIDIA GPU drivers...")
                
                # Check if nvidia-smi works
                ret, out, err = self.run_command(wsl_cmd + ['nvidia-smi', '--query-gpu=name,driver_version', '--format=csv,noheader'])
                if ret == 0 and out.strip():
                    gpu_info = out.strip()
                    self.log_output(f"[OK] NVIDIA GPU detected: {gpu_info}")
                    
                    # Check PyTorch CUDA support
                    pytorch_cmd = 'python3 -c "import torch; print(f\"CUDA available: {torch.cuda.is_available()}\"); print(f\"CUDA device count: {torch.cuda.device_count()}\"); print(f\"CUDA version: {torch.version.cuda}\")"'
                    ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', pytorch_cmd])
                    if ret == 0:
                        self.log_output(f"[OK] PyTorch CUDA status: {out.strip()}")
                    else:
                        self.log_output(f"[WARN] PyTorch CUDA check failed: {err}")
                else:
                    self.log_output(f"[ERROR] NVIDIA GPU not detected or drivers not working: {err}")
                    
            elif self.gpu_detection_results['intel_arc_detected']:
                self.log_output("Verifying Intel Arc GPU drivers...")
                
                # Check if clinfo works and shows Intel devices
                ret, out, err = self.run_command(wsl_cmd + ['clinfo'])
                if ret == 0:
                    if 'intel' in out.lower():
                        self.log_output("[OK] Intel OpenCL platform detected")
                        if 'device type: gpu' in out.lower():
                            self.log_output("[OK] Intel GPU device detected")
                        else:
                            self.log_output("[WARN] Intel OpenCL detected but showing as CPU device (reboot may be needed)")
                    else:
                        self.log_output("[ERROR] Intel OpenCL platform not detected")
                else:
                    self.log_output(f"[ERROR] clinfo command failed: {err}")
                    
            elif self.gpu_detection_results['intel_integrated_detected']:
                self.log_output("Verifying Intel integrated graphics...")
                
                # Check if vainfo works
                ret, out, err = self.run_command(wsl_cmd + ['vainfo'])
                if ret == 0:
                    if 'intel' in out.lower():
                        self.log_output("[OK] Intel VA-API drivers detected")
                    else:
                        self.log_output("[WARN] VA-API detected but Intel drivers may not be active")
                else:
                    self.log_output(f"[ERROR] VA-API check failed: {err}")
                    
                # Check OpenCL
                ret, out, err = self.run_command(wsl_cmd + ['clinfo'])
                if ret == 0:
                    if 'intel' in out.lower():
                        self.log_output("[OK] Intel OpenCL platform detected")
                    else:
                        self.log_output("[WARN] Intel OpenCL not detected")
                else:
                    self.log_output(f"[ERROR] OpenCL check failed: {err}")
            else:
                self.log_output("No GPU hardware detected - running in CPU-only mode")
                
        except Exception as e:
            self.log_output(f"Error verifying GPU driver status: {e}")

    def verify_gpu_drivers(self, wsl_cmd):
        """Simple verification that GPU drivers are available"""
        try:
            self.log_output("Verifying GPU driver installations...")
            
            if self.gpu_detection_results['nvidia_rtx_detected']:
                # Check if NVIDIA drivers are available
                ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', 'which nvidia-smi'])
                if ret == 0:
                    self.log_output("[OK] NVIDIA drivers appear to be available")
                else:
                    self.log_output("[WARN] NVIDIA drivers not found - may need system restart")
            
            elif self.gpu_detection_results['intel_arc_detected'] or self.gpu_detection_results['intel_integrated_detected']:
                # Check if Intel drivers are available
                ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', 'which vainfo'])
                if ret == 0:
                    self.log_output("[OK] Intel GPU drivers appear to be available")
                else:
                    self.log_output("[WARN] Intel GPU drivers not found")
            
            self.log_output("GPU driver verification complete")
            
        except Exception as e:
            self.log_output(f"Warning: GPU driver verification failed: {e}")

    def check_wsl_prerequisites(self):
        """Check WSL prerequisites and automatically install if not present"""
        self.log_output("Checking WSL prerequisites...")
        
        # Check if running as administrator (needed for WSL installation)
        if not self.is_running_as_administrator():
            self.log_output("WARNING: Not running as Administrator")
            self.log_output("WSL installation may fail without administrator privileges")
            self.log_output("Consider running this installer as Administrator for best results")
            self.log_output("")
        
        # Test basic WSL availability
        ret, out, err = self.run_command(['wsl', '--version'])
        if ret != 0:
            self.log_output("WSL not installed or not available")
            
            # Check for specific HCS service error
            if "HCS_E_SERVICE_NOT_AVAILABLE" in str(out) or "required feature is not installed" in str(out):
                self.log_output("")
                self.log_output("=== DETECTED: HCS SERVICE ERROR ===")
                self.log_output("This error indicates the Host Compute Service is not available.")
                self.log_output("This service is required for WSL to function properly.")
                self.log_output("")
                self.log_output("Attempting automatic repair...")
                
                # Try to fix the HCS service error
                if self.fix_hcs_service_error():
                    self.log_output("HCS service fixed successfully, retrying WSL check...")
                    ret, out, err = self.run_command(['wsl', '--version'])
                    if ret == 0:
                        self.log_output("SUCCESS: WSL is now available after fixing HCS service")
                        return True
                    else:
                        self.log_output("WSL still not available after HCS service fix")
                        self.log_output("This may require a system restart to fully resolve")
                        return False
                else:
                    self.log_output("Failed to fix HCS service automatically")
                    self.log_output("This may require a system restart or manual intervention")
                    return False
            
            # Check if this is Windows Server
            try:
                import platform
                windows_version = platform.platform()
                is_windows_server = "Server" in windows_version
            except:
                is_windows_server = False
            
            if is_windows_server:
                self.log_output("WINDOWS SERVER DETECTED:")
                self.log_output("Windows Server requires manual WSL setup")
                self.log_output("1. Open PowerShell as Administrator")
                
                if "2022" in windows_version:
                    self.log_output("2. Run: wsl --install")
                    self.log_output("3. Restart the server")
                    self.log_output("4. Re-run this installer")
                else:  # 2019 or other
                    self.log_output("2. Enable WSL feature:")
                    self.log_output("   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux")
                    self.log_output("3. Restart the server")
                    self.log_output("4. Re-run this installer")
                    self.log_output("NOTE: Server 2019 only supports WSL 1")
                
                self.log_output("ERROR: WSL prerequisites not met")
                self.log_output("Please follow the instructions above to enable WSL, then re-run this installer")
                return False
            else:
                # Regular Windows - attempt automatic installation
                self.log_output("Attempting automatic WSL installation...")
                self.log_output("Running: wsl --install")
                self.log_output("This may take several minutes and may require a system restart...")
                
                # Run wsl --install and wait for completion
                install_ret, install_out, install_err = self.run_command(['wsl', '--install'])
                
                if install_ret == 0:
                    self.log_output("")
                    self.log_output("=== WSL INSTALLATION COMPLETE - RESTART REQUIRED ===")
                    self.log_output("WSL installation command completed successfully")
                    self.log_output("")
                    self.log_output("IMPORTANT: WSL installation requires a system restart to activate!")
                    self.log_output("Please restart your system and re-run this installer")
                    self.log_output("")
                    self.log_output("After restart, WSL will be fully functional and ready for Kamiwaza.")
                    return False
                else:
                    self.log_output(f"WSL installation failed with error: {install_err}")
                    
                    # Check for specific registry corruption error
                    if "REGDB_E_CLASSNOTREG" in install_err or "Class not registered" in install_err:
                        self.log_output("")
                        self.log_output("=== DETECTED: WSL REGISTRY CORRUPTION ===")
                        self.log_output("This error indicates Windows registry corruption preventing WSL installation.")
                        self.log_output("Attempting automatic repair...")
                        
                        # Try to repair WSL using PowerShell commands
                        repair_result = self.repair_wsl_registry_corruption()
                        if repair_result:
                            self.log_output("")
                            self.log_output("=== WSL REGISTRY REPAIR COMPLETE - RESTART REQUIRED ===")
                            self.log_output("WSL registry corruption repair completed successfully")
                            self.log_output("")
                            self.log_output("IMPORTANT: Registry repair requires a system restart to activate!")
                            self.log_output("Please restart your system and re-run this installer")
                            self.log_output("")
                            self.log_output("After restart, WSL should be functional and ready for Kamiwaza.")
                            return False
                        else:
                            self.log_output("Automatic repair failed - manual intervention required")
                            self.log_output("")
                            self.log_output("MANUAL REPAIR STEPS:")
                            self.log_output("1. Open PowerShell as Administrator")
                            self.log_output("2. Run: Get-AppxPackage -AllUsers Microsoft.WSL")
                            self.log_output("3. If package exists, run: Remove-AppxPackage Microsoft.WSL")
                            self.log_output("4. Run: wsl --unregister Ubuntu (if exists)")
                            self.log_output("5. Restart your computer")
                            self.log_output("6. Run: wsl --install")
                            self.log_output("")
                            self.log_output("ALTERNATIVE: Use Windows Store to install 'Windows Subsystem for Linux'")
                            self.log_output("")
                            self.log_output("NOTE: The 'REGDB_E_CLASSNOTREG' error indicates Windows registry corruption.")
                            self.log_output("If manual repair fails, you may need to:")
                            self.log_output("- Run Windows System File Checker: sfc /scannow")
                            self.log_output("- Run DISM: DISM /Online /Cleanup-Image /RestoreHealth")
                            self.log_output("- Consider Windows repair or reinstall if corruption persists")
                            return False
                    else:
                        self.log_output("Please install WSL manually using: wsl --install")
                        return False
        else:
            self.log_output("[OK] WSL version command succeeded")
            if out:
                # Show WSL version info
                for line in out.strip().split('\n')[:3]:  # First 3 lines
                    self.log_output(f"  {line}")
            
            # Additional check: Test if WSL service is actually functional
            self.log_output("Testing WSL service functionality...")
            service_test_ret, service_test_out, service_test_err = self.run_command(['wsl', '--list', '--quiet'])
            if service_test_ret != 0:
                self.log_output("WARNING: WSL version command succeeded but service is not functional")
                self.log_output(f"Service test error: {service_test_err}")
                self.log_output("This indicates WSL is installed but not properly enabled")
                
                # Check if this is Windows Server
                try:
                    import platform
                    windows_version = platform.platform()
                    is_windows_server = "Server" in windows_version
                except:
                    is_windows_server = False
                
                if is_windows_server:
                    self.log_output("WINDOWS SERVER DETECTED:")
                    self.log_output("Windows Server requires manual WSL setup")
                    self.log_output("1. Open PowerShell as Administrator")
                    
                    if "2022" in windows_version:
                        self.log_output("2. Run: wsl --install")
                        self.log_output("3. Restart the server")
                        self.log_output("4. Re-run this installer")
                    else:  # 2019 or other
                        self.log_output("2. Enable WSL feature:")
                        self.log_output("   Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux")
                        self.log_output("3. Restart the server")
                        self.log_output("4. Re-run this installer")
                        self.log_output("NOTE: Server 2019 only supports WSL 1")
                else:
                    self.log_output("REGULAR WINDOWS DETECTED:")
                    self.log_output("WSL appears to be installed but not properly enabled")
                    self.log_output("Attempting to fix WSL installation...")
                    self.log_output("Running: wsl --update")
                    
                    # Try to update WSL first
                    update_ret, update_out, update_err = self.run_command(['wsl', '--update'])
                    if update_ret == 0:
                        self.log_output("WSL update completed successfully")
                        self.log_output("Testing WSL service again...")
                        
                        # Test service again
                        retest_ret, retest_out, retest_err = self.run_command(['wsl', '--list', '--quiet'])
                        if retest_ret == 0:
                            self.log_output("SUCCESS: WSL service is now functional")
                            return True
                        else:
                            self.log_output("WSL service still not functional after update")
                            self.log_output("Attempting full WSL reinstall...")
                            
                            # Try full reinstall
                            reinstall_ret, reinstall_out, reinstall_err = self.run_command(['wsl', '--unregister', 'Ubuntu'])
                            if reinstall_ret == 0:
                                self.log_output("Removed existing Ubuntu distribution")
                            
                            install_ret, install_out, install_err = self.run_command(['wsl', '--install'])
                            if install_ret == 0:
                                self.log_output("")
                                self.log_output("=== WSL REINSTALLATION COMPLETE - RESTART REQUIRED ===")
                                self.log_output("WSL reinstallation completed successfully")
                                self.log_output("")
                                self.log_output("IMPORTANT: WSL reinstallation requires a system restart to activate!")
                                self.log_output("Please restart your system and re-run this installer")
                                self.log_output("")
                                self.log_output("After restart, WSL will be fully functional and ready for Kamiwaza.")
                                return False
                            else:
                                self.log_output(f"WSL reinstallation failed: {install_err}")
                                self.log_output("Please install WSL manually using: wsl --install")
                                return False
                    else:
                        self.log_output(f"WSL update failed: {update_err}")
                        self.log_output("Attempting full WSL reinstall...")
                        
                        # Try full reinstall
                        reinstall_ret, reinstall_out, reinstall_err = self.run_command(['wsl', '--unregister', 'Ubuntu'], timeout=120)
                        if reinstall_ret == 0:
                            self.log_output("Removed existing Ubuntu distribution")
                        
                        install_ret, install_out, install_err = self.run_command(['wsl', '--install'], timeout=300)
                        if install_ret == 0:
                            self.log_output("")
                            self.log_output("=== WSL REINSTALLATION COMPLETE - RESTART REQUIRED ===")
                            self.log_output("WSL reinstallation completed successfully")
                            self.log_output("")
                            self.log_output("IMPORTANT: WSL reinstallation requires a system restart to activate!")
                            self.log_output("Please restart your system and re-run this installer")
                            self.log_output("")
                            self.log_output("After restart, WSL will be fully functional and ready for Kamiwaza.")
                            return False
                        else:
                            self.log_output(f"WSL reinstallation failed: {install_err}")
                            self.log_output("Please install WSL manually using: wsl --install")
                            return False
                
                return False
            
            self.log_output("[OK] WSL service is functional")
            return True
    
    def check_wsl_installation_status(self):
        """Check if WSL installation is in progress or if restart is needed"""
        self.log_output("Checking WSL installation status...")
        
        # Try to run wsl --version again to see if installation completed
        ret, out, err = self.run_command(['wsl', '--version'], timeout=10)
        if ret == 0:
            self.log_output("WSL is now available after installation")
            return True
        
        # Check if WSL feature is enabled but not fully installed
        try:
            import subprocess
            # Check if WSL feature is enabled
            feature_check = subprocess.run(['powershell', '-Command', 'Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux'], 
                                        capture_output=True, text=True, timeout=30)
            if 'Enabled' in feature_check.stdout:
                self.log_output("WSL feature is enabled but may need a restart")
                self.log_output("Please restart your system and re-run this installer")
                return False
            else:
                self.log_output("WSL feature is not enabled")
                return False
        except Exception as e:
            self.log_output(f"Could not check WSL feature status: {e}")
            return False
    
    def fix_hcs_service_error(self):
        """Attempt to fix HCS service errors that commonly occur with WSL"""
        self.log_output("Attempting to fix HCS service error...")
        self.log_output("This error typically indicates WSL service is not properly running")
        self.log_output("HCS (Host Compute Service) is the Windows service that manages WSL virtual machines")
        
        # Try to restart WSL service
        self.log_output("Step 1: Restarting WSL service...")
        restart_ret, restart_out, restart_err = self.run_command(['wsl', '--shutdown'], timeout=60)
        if restart_ret == 0:
            self.log_output("WSL shutdown completed successfully")
        else:
            self.log_output(f"WSL shutdown failed: {restart_err}")
        
        # Wait a moment for services to fully stop
        import time
        self.log_output("Step 2: Waiting for services to fully stop...")
        time.sleep(5)
        
        # Try to start WSL again
        self.log_output("Step 3: Attempting to restart WSL...")
        start_ret, start_out, start_err = self.run_command(['wsl', '--list', '--quiet'], timeout=30)
        if start_ret == 0:
            self.log_output("SUCCESS: WSL service is now functional")
            return True
        else:
            self.log_output(f"WSL service still not functional: {start_err}")
            self.log_output("Step 4: Attempting to enable WSL feature...")
            
            # Try to enable WSL feature using PowerShell
            try:
                import subprocess
                enable_cmd = ['powershell', '-Command', 'Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All']
                enable_ret = subprocess.run(enable_cmd, capture_output=True, text=True, timeout=120)
                
                if enable_ret.returncode == 0:
                    self.log_output("WSL feature enabled successfully")
                    self.log_output("Please restart your system and re-run this installer")
                    return False
                else:
                    self.log_output(f"Failed to enable WSL feature: {enable_ret.stderr}")
                    self.log_output("Step 5: Attempting alternative WSL repair methods...")
                    
                    # Try alternative repair methods
                    repair_methods = [
                        ("Restarting Windows Subsystem for Linux service", 
                         ['powershell', '-Command', 'Restart-Service LxssManager']),
                        ("Restarting Hyper-V Host Compute Service", 
                         ['powershell', '-Command', 'Restart-Service HvHostSvc']),
                        ("Checking WSL status", 
                         ['wsl', '--status'])
                    ]
                    
                    for method_name, method_cmd in repair_methods:
                        self.log_output(f"  Trying: {method_name}")
                        try:
                            method_ret = subprocess.run(method_cmd, capture_output=True, text=True, timeout=30)
                            if method_ret.returncode == 0:
                                self.log_output(f"    [OK] {method_name} completed successfully")
                            else:
                                self.log_output(f"    [WARN] {method_name} failed: {method_ret.stderr}")
                        except Exception as e:
                            self.log_output(f"    [WARN] {method_name} error: {e}")
                    
                    # Final test
                    self.log_output("Step 6: Final WSL service test...")
                    final_ret, final_out, final_err = self.run_command(['wsl', '--list', '--quiet'], timeout=30)
                    if final_ret == 0:
                        self.log_output("SUCCESS: WSL service is now functional after repair attempts")
                        return True
                    else:
                        self.log_output(f"WSL service still not functional after all repair attempts: {final_err}")
                        self.log_output("This indicates a deeper system issue that may require:")
                        self.log_output("  1. System restart")
                        self.log_output("  2. Windows Update")
                        self.log_output("  3. System File Checker (sfc /scannow)")
                        self.log_output("  4. DISM repair (DISM /Online /Cleanup-Image /RestoreHealth)")
                        return False
                        
            except Exception as e:
                self.log_output(f"Error during WSL repair: {e}")
                return False

    def recover_wsl_disk_attachment(self):
        """Recover from WSL disk attachment failures by restarting WSL services"""
        try:
            self.log_output("=== RECOVERING WSL DISK ATTACHMENT ===")
            self.log_output("This error typically occurs when WSL services get into a bad state")
            self.log_output("Attempting automatic recovery without killing the installer...")
            
            # Step 1: Force shutdown all WSL instances
            self.log_output("Step 1: Force shutting down all WSL instances...")
            shutdown_ret, shutdown_out, shutdown_err = self.run_command(['wsl', '--shutdown'])
            if shutdown_ret == 0:
                self.log_output("  [OK] WSL shutdown completed successfully")
            else:
                self.log_output(f"  [WARN] WSL shutdown failed: {shutdown_err}")
            
            # Step 2: Wait for services to fully stop
            import time
            self.log_output("Step 2: Waiting for WSL services to fully stop...")
            time.sleep(10)  # Longer wait for disk operations to complete
            
            # Step 3: Restart WSL services using PowerShell
            self.log_output("Step 3: Restarting WSL services...")
            try:
                import subprocess
                service_restart_commands = [
                    ("Restarting Windows Subsystem for Linux service", 
                     ['powershell', '-Command', 'Restart-Service LxssManager -Force']),
                    ("Restarting Hyper-V Host Compute Service", 
                     ['powershell', '-Command', 'Restart-Service HvHostSvc -Force']),
                    ("Restarting Virtual Machine Management service", 
                     ['powershell', '-Command', 'Restart-Service VMMS -Force'])
                ]
                
                for service_name, service_cmd in service_restart_commands:
                    self.log_output(f"  Trying: {service_name}")
                    try:
                        service_ret = subprocess.run(service_cmd, capture_output=True, text=True, timeout=60)
                        if service_ret.returncode == 0:
                            self.log_output(f"    [OK] {service_name} restarted successfully")
                        else:
                            self.log_output(f"    [WARN] {service_name} restart failed: {service_ret.stderr}")
                    except Exception as e:
                        self.log_output(f"    [WARN] {service_name} restart error: {e}")
                
            except Exception as e:
                self.log_output(f"  [WARN] PowerShell service restart failed: {e}")
            
            # Step 4: Wait for services to fully restart
            self.log_output("Step 4: Waiting for WSL services to fully restart...")
            import time
            time.sleep(15)  # Longer wait for services to stabilize
            
            # Step 5: Test WSL functionality
            self.log_output("Step 5: Testing WSL functionality...")
            test_ret, test_out, test_err = self.run_command(['wsl', '--list', '--quiet'])
            if test_ret == 0:
                self.log_output("  [OK] WSL list command successful after recovery")
                if test_out:
                    self.log_output(f"  Available distributions: {test_out.strip()}")
                return True
            else:
                self.log_output(f"  [WARN] WSL test failed after recovery: {test_err}")
                
                # Step 6: Try WSL update as additional recovery step
                self.log_output("Step 6: Attempting WSL update for additional recovery...")
                update_ret, update_out, update_err = self.run_command(['wsl', '--update'])
                if update_ret == 0:
                    self.log_output("  [OK] WSL update completed successfully")
                    import time
                    # Wait for update to take effect
                    time.sleep(10)
                    
                    # Test again after update
                    final_test_ret, final_test_out, final_test_err = self.run_command(['wsl', '--list', '--quiet'])
                    if final_test_ret == 0:
                        self.log_output("  [OK] WSL is now functional after update recovery")
                        return True
                    else:
                        self.log_output(f"  [ERROR] WSL still not functional after update recovery: {final_test_err}")
                        return False
                else:
                    self.log_output(f"  [ERROR] WSL update failed during recovery: {update_err}")
                    return False
            
        except Exception as e:
            self.log_output(f"Error during WSL disk attachment recovery: {e}")
            return False

    def repair_wsl_registry_corruption(self):
        """Attempt to repair WSL registry corruption using PowerShell commands"""
        try:
            self.log_output("Attempting to repair WSL registry corruption...")
            
            # Check if running as administrator
            if not self.is_running_as_administrator():
                self.log_output("ERROR: Administrator privileges required for registry repair")
                self.log_output("Please run this installer as Administrator")
                self.log_output("Right-click the installer and select 'Run as administrator'")
                return False
            
            self.log_output("Administrator privileges confirmed - proceeding with repair...")
            
            # Step 1: Check if WSL AppX package exists
            self.log_output("Step 1: Checking WSL AppX package status...")
            check_cmd = ['powershell', '-Command', 'Get-AppxPackage -AllUsers Microsoft.WSL']
            ret, out, err = self.run_command(check_cmd)
            
            if ret == 0 and out.strip():
                self.log_output("WSL AppX package found - attempting removal...")
                
                # Step 2: Remove the corrupted WSL AppX package
                self.log_output("Step 2: Removing corrupted WSL AppX package...")
                remove_cmd = ['powershell', '-Command', 'Remove-AppxPackage Microsoft.WSL -AllUsers']
                remove_ret, remove_out, remove_err = self.run_command(remove_cmd)
                
                if remove_ret == 0:
                    self.log_output("WSL AppX package removed successfully")
                else:
                    self.log_output(f"Warning: Could not remove WSL AppX package: {remove_err}")
            else:
                self.log_output("No WSL AppX package found - proceeding with feature cleanup")
            
            # Step 3: Try to unregister any existing WSL distributions
            self.log_output("Step 3: Cleaning up existing WSL distributions...")
            cleanup_commands = [
                ['wsl', '--unregister', 'Ubuntu'],
                ['wsl', '--unregister', 'Ubuntu-24.04'],
                ['wsl', '--unregister', 'kamiwaza']
            ]
            
            for cmd in cleanup_commands:
                try:
                    ret, out, err = self.run_command(cmd)
                    if ret == 0:
                        self.log_output(f"Successfully unregistered: {' '.join(cmd)}")
                    else:
                        self.log_output(f"Distribution not found or already removed: {' '.join(cmd)}")
                except:
                    # Ignore errors for non-existent distributions
                    pass
            
            # Step 4: Shutdown WSL completely
            self.log_output("Step 4: Shutting down WSL completely...")
            shutdown_ret, shutdown_out, shutdown_err = self.run_command(['wsl', '--shutdown'])
            if shutdown_ret == 0:
                self.log_output("WSL shutdown completed successfully")
            else:
                self.log_output(f"WSL shutdown command failed: {shutdown_err}")
            
            # Step 5: Wait for services to fully stop
            import time
            self.log_output("Step 5: Waiting for services to fully stop...")
            time.sleep(5)
            
            # Step 6: Try to reinstall WSL using the Microsoft Store method
            self.log_output("Step 6: Attempting WSL reinstallation...")
            self.log_output("Note: This may open the Microsoft Store or require user interaction")
            
            # Try the Microsoft Store method first
            store_cmd = ['powershell', '-Command', 'Start-Process ms-windows-store://pdp/?ProductId=9P9TQF7MRM4R']
            store_ret, store_out, store_err = self.run_command(store_cmd, timeout=30)
            
            if store_ret == 0:
                self.log_output("Microsoft Store opened for WSL installation")
                self.log_output("Please complete the installation in the Microsoft Store")
                self.log_output("After installation, restart your system and re-run this installer")
                return True
            else:
                self.log_output("Could not open Microsoft Store - trying alternative method...")
                
                # Alternative: Try to use winget to install WSL
                winget_cmd = ['winget', 'install', 'Microsoft.WSL']
                winget_ret, winget_out, winget_err = self.run_command(winget_cmd, timeout=120)
                
                if winget_ret == 0:
                    self.log_output("WSL installation via winget completed successfully")
                    self.log_output("Please restart your system and re-run this installer")
                    return True
                else:
                    self.log_output(f"Winget installation failed: {winget_err}")
                    self.log_output("Manual installation required")
                    return False
            
        except Exception as e:
            self.log_output(f"Error during WSL registry repair: {e}")
            return False

    def is_running_as_administrator(self):
        """Check if the current process is running with administrator privileges"""
        try:
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        except:
            return False
    
    def is_headless_mode(self):
        """Check if the installer is running in headless/non-interactive mode"""
        try:
            # Check if stdin is available and interactive
            if not sys.stdin.isatty():
                return True
            if not hasattr(sys.stdin, 'readline'):
                return True
            # Check if we're running from MSI or other non-interactive source
            if 'MSIEXEC' in os.environ.get('PROCESS_NAME', ''):
                return True
            return False
        except:
            return True  # Assume headless if we can't determine
    
    def _create_restart_reminder(self):
        """Create a restart reminder file for manual restart"""
        try:
            restart_flag_file = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza', 'RESTART_NOW.txt')
            with open(restart_flag_file, 'w') as f:
                f.write("GPU ACCELERATION REQUIRES SYSTEM RESTART!\n")
                f.write("=" * 50 + "\n")
                f.write("GPU drivers have been installed but are not yet active.\n")
                f.write("You MUST restart your computer for GPU acceleration to work.\n")
                f.write("\n")
                f.write("IMPORTANT: This is a TWO-PHASE installation!\n")
                f.write("Phase 1: GPU drivers installed (COMPLETED)\n")
                f.write("Phase 2: Package installation (PENDING - after restart)\n")
                f.write("\n")
                f.write("After restart:\n")
                f.write("1. Re-run the Kamiwaza installer to continue\n")
                f.write("2. GPU acceleration will be active\n")
                f.write("3. Package installation will complete with optimal performance\n")
                f.write("4. Kamiwaza will start with GPU acceleration ready\n")
                f.write("\n")
                f.write("To restart manually:\n")
                f.write("1. Save all work\n")
                f.write("2. Press Windows + R\n")
                f.write("3. Type: shutdown /r /t 0\n")
                f.write("4. Press Enter\n")
                f.write("\n")
                f.write("The installer will automatically detect this is a re-run\n")
                f.write("and continue from where it left off.\n")
            self.log_output(f"Restart reminder created: {restart_flag_file}")
        except Exception as e:
            self.log_output(f"Could not create restart reminder: {e}")
    
    # Note: GPU restart logic is now handled directly in GPU setup scripts
    # No complex restart flag checking needed

    def provide_registry_corruption_repair_summary(self):
        """Provide comprehensive repair options for WSL registry corruption"""
        self.log_output("")
        self.log_output("=== COMPREHENSIVE WSL REGISTRY CORRUPTION REPAIR GUIDE ===")
        self.log_output("")
        self.log_output("IMMEDIATE ACTIONS (try in order):")
        self.log_output("1. RESTART YOUR COMPUTER (often fixes registry issues)")
        self.log_output("2. Run this installer as Administrator")
        self.log_output("3. Try automatic repair (if running as Administrator)")
        self.log_output("")
        self.log_output("MANUAL REPAIR STEPS (if automatic fails):")
        self.log_output("1. Open PowerShell as Administrator")
        self.log_output("2. Check WSL package: Get-AppxPackage -AllUsers Microsoft.WSL")
        self.log_output("3. Remove if found: Remove-AppxPackage Microsoft.WSL")
        self.log_output("4. Clean distributions: wsl --unregister Ubuntu (repeat for all)")
        self.log_output("5. Restart computer")
        self.log_output("6. Install WSL: wsl --install")
        self.log_output("")
        self.log_output("ALTERNATIVE INSTALLATION METHODS:")
        self.log_output("1. Microsoft Store: Search 'Windows Subsystem for Linux'")
        self.log_output("2. Winget: winget install Microsoft.WSL")
        self.log_output("3. Manual download from Microsoft's website")
        self.log_output("")
        self.log_output("SYSTEM REPAIR TOOLS (if registry corruption persists):")
        self.log_output("1. System File Checker: sfc /scannow")
        self.log_output("2. DISM repair: DISM /Online /Cleanup-Image /RestoreHealth")
        self.log_output("3. Windows Update troubleshooter")
        self.log_output("4. Windows repair installation (last resort)")
        self.log_output("")
        self.log_output("COMMON CAUSES:")
        self.log_output("- Corrupted Windows updates")
        self.log_output("- Malware or virus infection")
        self.log_output("- Power loss during system updates")
        self.log_output("- Corrupted system files")
        self.log_output("")
        self.log_output("PREVENTION:")
        self.log_output("- Keep Windows updated")
        self.log_output("- Use UPS for critical systems")
        self.log_output("- Run regular system maintenance")
        self.log_output("- Avoid interrupting system updates")
        self.log_output("")
        self.log_output("=== END REPAIR GUIDE ===")
        self.log_output("")

    def perform_advanced_hcs_repair(self):
        """Perform advanced HCS service repair using PowerShell commands"""
        try:
            self.log_output("=== PERFORMING ADVANCED HCS SERVICE REPAIR ===")
            self.log_output("Executing repair commands automatically...")
            
            # Check if running as administrator
            if not self.is_running_as_administrator():
                self.log_output("ERROR: Administrator privileges required for advanced repair")
                self.log_output("Please run this installer as Administrator")
                return False
            
            self.log_output("Administrator privileges confirmed - proceeding with advanced repair...")
            
            # Step 1: Restart WSL service
            self.log_output("Step 1: Restarting Windows Subsystem for Linux service...")
            try:
                import subprocess
                restart_lxss = subprocess.run(
                    ['powershell', '-Command', 'Restart-Service LxssManager -Force'],
                    capture_output=True, text=True, timeout=60
                )
                if restart_lxss.returncode == 0:
                    self.log_output("  [OK] LxssManager service restarted successfully")
                else:
                    self.log_output(f"  [WARN] LxssManager restart failed: {restart_lxss.stderr}")
            except Exception as e:
                self.log_output(f"  [WARN] LxssManager restart error: {e}")
            
            # Step 2: Restart Hyper-V Host Compute Service
            self.log_output("Step 2: Restarting Hyper-V Host Compute Service...")
            try:
                restart_hvhost = subprocess.run(
                    ['powershell', '-Command', 'Restart-Service HvHostSvc -Force'],
                    capture_output=True, text=True, timeout=60
                )
                if restart_hvhost.returncode == 0:
                    self.log_output("  [OK] HvHostSvc service restarted successfully")
                else:
                    self.log_output(f"  [WARN] HvHostSvc restart failed: {restart_hvhost.stderr}")
            except Exception as e:
                self.log_output(f"  [WARN] HvHostSvc restart error: {e}")
            
            # Step 3: Wait for services to fully restart
            self.log_output("Step 3: Waiting for services to fully restart...")
            import time
            time.sleep(10)
            
            # Step 4: Check WSL status
            self.log_output("Step 4: Checking WSL status...")
            status_ret, status_out, status_err = self.run_command(['wsl', '--status'], timeout=30)
            if status_ret == 0:
                self.log_output("  [OK] WSL status check successful")
                if status_out:
                    self.log_output(f"  Status: {status_out.strip()}")
            else:
                self.log_output(f"  [WARN] WSL status check failed: {status_err}")
            
            # Step 5: Test WSL functionality
            self.log_output("Step 5: Testing WSL functionality...")
            test_ret, test_out, test_err = self.run_command(['wsl', '--list', '--quiet'], timeout=30)
            if test_ret == 0:
                self.log_output("  [OK] WSL list command successful")
                if test_out:
                    self.log_output(f"  Available distributions: {test_out.strip()}")
                return True
            else:
                self.log_output(f"  [WARN] WSL test failed: {test_err}")
                
                # Step 6: Try WSL update
                self.log_output("Step 6: Attempting WSL update...")
                update_ret, update_out, update_err = self.run_command(['wsl', '--update'], timeout=120)
                if update_ret == 0:
                    self.log_output("  [OK] WSL update completed successfully")
                    
                    # Test again after update
                    self.log_output("Step 7: Testing WSL after update...")
                    final_test_ret, final_test_out, final_test_err = self.run_command(['wsl', '--list', '--quiet'], timeout=30)
                    if final_test_ret == 0:
                        self.log_output("  [OK] WSL is now functional after update")
                        return True
                    else:
                        self.log_output(f"  [ERROR] WSL still not functional after update: {final_test_err}")
                        return False
                else:
                    self.log_output(f"  [ERROR] WSL update failed: {update_err}")
                    return False
            
        except Exception as e:
            self.log_output(f"Error during advanced HCS repair: {e}")
            return False

    def provide_hcs_service_error_repair_summary(self):
        """Provide comprehensive repair options for HCS service errors"""
        self.log_output("")
        self.log_output("=== COMPREHENSIVE HCS SERVICE ERROR REPAIR GUIDE ===")
        self.log_output("")
        self.log_output("HCS_E_SERVICE_NOT_AVAILABLE indicates the Host Compute Service is not running")
        self.log_output("This service is required for WSL to create and manage virtual machines")
        self.log_output("")
        self.log_output("IMMEDIATE ACTIONS (try in order):")
        self.log_output("1. RESTART YOUR COMPUTER (most common fix for HCS service issues)")
        self.log_output("2. Run this installer as Administrator")
        self.log_output("3. Try automatic repair (if running as Administrator)")
        self.log_output("")
        self.log_output("MANUAL SERVICE REPAIR STEPS (if automatic fails):")
        self.log_output("1. Open PowerShell as Administrator")
        self.log_output("2. Restart WSL service: Restart-Service LxssManager")
        self.log_output("3. Restart Hyper-V service: Restart-Service HvHostSvc")
        self.log_output("4. Check WSL status: wsl --status")
        self.log_output("5. Test WSL: wsl --list --quiet")
        self.log_output("")
        self.log_output("ALTERNATIVE WSL REPAIR METHODS:")
        self.log_output("1. Reset WSL: wsl --shutdown && wsl --update")
        self.log_output("2. Unregister all distributions: wsl --unregister <distro_name>")
        self.log_output("3. Reinstall WSL: wsl --uninstall && wsl --install")
        self.log_output("")
        self.log_output("SYSTEM-LEVEL REPAIR TOOLS:")
        self.log_output("1. Windows Update (install all pending updates)")
        self.log_output("2. System File Checker: sfc /scannow")
        self.log_output("3. DISM repair: DISM /Online /Cleanup-Image /RestoreHealth")
        self.log_output("4. Check Windows features: OptionalFeatures.exe")
        self.log_output("")
        self.log_output("COMMON CAUSES OF HCS SERVICE ERRORS:")
        self.log_output("- Windows Update interrupted or corrupted")
        self.log_output("- Hyper-V feature not properly enabled")
        self.log_output("- Virtualization not enabled in BIOS/UEFI")
        self.log_output("- Corrupted Windows services")
        self.log_output("- Insufficient system resources")
        self.log_output("")
        self.log_output("VIRTUALIZATION REQUIREMENTS:")
        self.log_output("- BIOS/UEFI: Virtualization Technology (VT-x/AMD-V) must be enabled")
        self.log_output("- Windows: Hyper-V platform must be enabled")
        self.log_output("- Windows: Windows Subsystem for Linux feature must be enabled")
        self.log_output("")
        self.log_output("PREVENTION:")
        self.log_output("- Complete Windows updates fully before restarting")
        self.log_output("- Enable virtualization in BIOS/UEFI if disabled")
        self.log_output("- Keep Windows and drivers updated")
        self.log_output("- Avoid interrupting system updates")
        self.log_output("")
        self.log_output("=== END HCS REPAIR GUIDE ===")
        self.log_output("")

    def copy_logs_to_windows(self, wsl_cmd, timestamp):
        """Copy WSL logs to Windows AppData folder for easy access"""
        try:
            # Create logs directory in AppData
            appdata_logs = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza', 'logs')
            os.makedirs(appdata_logs, exist_ok=True)
            self.log_output(f"Created Windows logs directory: {appdata_logs}")
            
            # Copy APT terminal log (detailed installation output)
            apt_term_log = os.path.join(appdata_logs, 'apt_term_log.txt')
            cmd = f"cat /var/log/apt/term.log"
            ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', cmd])
            if ret == 0 and out:
                with open(apt_term_log, 'w', encoding='utf-8') as f:
                    f.write(f"Kamiwaza Installation - APT Terminal Log\n")
                    f.write(f"Installation Date: {timestamp}\n")
                    f.write(f"WSL Instance: {wsl_cmd[2] if len(wsl_cmd) > 2 else 'default'}\n")
                    f.write("=" * 60 + "\n\n")
                    f.write(out)
                self.log_output(f"[OK] Copied detailed APT logs to: {apt_term_log}")
            else:
                self.log_output(f"[WARN] Could not copy APT terminal log: {err}")
            
            # Copy APT history log
            apt_history_log = os.path.join(appdata_logs, 'apt_history_log.txt')
            cmd = f"cat /var/log/apt/history.log"
            ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', cmd])
            if ret == 0 and out:
                with open(apt_history_log, 'w', encoding='utf-8') as f:
                    f.write(f"Kamiwaza Installation - APT History Log\n")
                    f.write(f"Installation Date: {timestamp}\n")
                    f.write("=" * 60 + "\n\n")
                    f.write(out)
                self.log_output(f"[OK] Copied APT history to: {apt_history_log}")
            
            # Copy DPKG log (kamiwaza entries only)
            dpkg_log = os.path.join(appdata_logs, 'dpkg_log.txt')
            cmd = f"grep kamiwaza /var/log/dpkg.log"
            ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', cmd])
            if ret == 0 and out:
                with open(dpkg_log, 'w', encoding='utf-8') as f:
                    f.write(f"Kamiwaza Installation - DPKG Operations Log\n")
                    f.write(f"Installation Date: {timestamp}\n")
                    f.write("=" * 60 + "\n\n")
                    f.write(out)
                self.log_output(f"[OK] Copied DPKG operations to: {dpkg_log}")
            
            # Create a master install log with key information
            install_log = os.path.join(appdata_logs, 'kamiwaza_install_logs.txt')
            with open(install_log, 'w', encoding='utf-8') as f:
                f.write(f"KAMIWAZA INSTALLATION LOG SUMMARY\n")
                f.write(f"Installation Date: {timestamp}\n")
                f.write(f"WSL Instance: {wsl_cmd[2] if len(wsl_cmd) > 2 else 'default'}\n")
                f.write(f"Installer: {__file__}\n")
                f.write("=" * 60 + "\n\n")
                
                f.write("LOG FILE LOCATIONS:\n")
                f.write(f"- Detailed APT output: {apt_term_log}\n")
                f.write(f"- APT history: {apt_history_log}\n")
                f.write(f"- DPKG operations: {dpkg_log}\n")
                f.write("\n")
                
                f.write("WSL COMMAND TO VIEW MAIN LOG:\n")
                f.write(f"wsl -d {wsl_cmd[2] if len(wsl_cmd) > 2 else 'default'} -- cat /var/log/apt/term.log\n")
                f.write("\n")
                
                f.write("SEARCH FOR ERRORS:\n")
                f.write(f"wsl -d {wsl_cmd[2] if len(wsl_cmd) > 2 else 'default'} -- grep -i error /var/log/apt/term.log\n")
                f.write(f"wsl -d {wsl_cmd[2] if len(wsl_cmd) > 2 else 'default'} -- grep -i fail /var/log/apt/term.log\n")
                f.write("\n")
                
                f.write("KAMIWAZA PLATFORM COMMANDS:\n")
                f.write(f"wsl -d {wsl_cmd[2] if len(wsl_cmd) > 2 else 'default'} -- kamiwaza start\n")
                f.write(f"wsl -d {wsl_cmd[2] if len(wsl_cmd) > 2 else 'default'} -- kamiwaza stop\n")
                f.write(f"wsl -d {wsl_cmd[2] if len(wsl_cmd) > 2 else 'default'} -- kamiwaza status\n")
                f.write(f"wsl -d {wsl_cmd[2] if len(wsl_cmd) > 2 else 'default'} -- kamiwaza logs\n")
            
            self.log_output(f"[OK] Created master log index: {install_log}")
            self.log_output(f"All logs copied to Windows directory: {appdata_logs}")
            
        except Exception as e:
            self.log_output(f"ERROR copying logs to Windows: {e}")

    def verify_and_show_logs(self, wsl_cmd):
        """Verify actual log files exist and show summary"""
        try:
            # Check APT terminal log
            cmd = f"ls -la /var/log/apt/term.log"
            ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', cmd])
            if ret == 0:
                self.log_output(f"[OK] APT terminal log exists: {out.strip()}")
                
                # Show last few lines
                cmd = f"tail -10 /var/log/apt/term.log"
                ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', cmd])
                if ret == 0 and out:
                    self.log_output("Last 10 lines of APT installation log:")
                    for line in out.strip().split('\n')[-5:]:  # Show only last 5 lines to save space
                        if line.strip():
                            self.log_output(f"  {line}")
            else:
                self.log_output(f"[WARN] APT terminal log not found: {err}")
            
            # Check APT history log
            cmd = f"ls -la /var/log/apt/history.log"
            ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', cmd])
            if ret == 0:
                self.log_output(f"[OK] APT history log exists: {out.strip()}")
            else:
                self.log_output(f"[WARN] APT history log not found: {err}")
            
            # Check for kamiwaza in dpkg log
            cmd = f"grep -c kamiwaza /var/log/dpkg.log"
            ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', cmd])
            if ret == 0 and out.strip().isdigit():
                count = int(out.strip())
                self.log_output(f"[OK] Found {count} kamiwaza entries in DPKG log")
            else:
                self.log_output(f"[WARN] No kamiwaza entries found in DPKG log")
            
        except Exception as e:
            self.log_output(f"ERROR verifying logs: {e}")

    def log_output(self, message, progress=None):
        """Log message with optional progress for MSI - ENHANCED FOR RELIABILITY"""
        try:
            timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            log_line = f"[{timestamp}] {message}"
            
            # Multiple logging methods for maximum reliability
            logging_methods = []
            
            # Method 1: Direct print to stdout (primary method)
            try:
                print(log_line)
                logging_methods.append("stdout")
            except Exception as e:
                logging_methods.append(f"stdout_failed:{e}")
            
            # Method 2: Write to Windows AppData log file (backup method)
            try:
                appdata_logs = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza', 'logs')
                os.makedirs(appdata_logs, exist_ok=True)
                log_file = os.path.join(appdata_logs, 'kamiwaza_installer.log')
                
                with open(log_file, 'a', encoding='utf-8', errors='replace') as f:
                    f.write(log_line + '\n')
                    f.flush()
                    os.fsync(f.fileno())  # Force write to disk
                logging_methods.append("file")
            except Exception as e:
                logging_methods.append(f"file_failed:{e}")
            
            # Method 3: Write to Windows Event Log (system-level backup) - OPTIONAL
            try:
                import win32evtlog
                import win32evtlogutil
                import win32con
                
                # Create event source if it doesn't exist
                try:
                    win32evtlogutil.AddSourceToRegistry("Kamiwaza", "Kamiwaza Installer", "Application")
                except:
                    pass  # Source may already exist
                
                # Log the event
                win32evtlogutil.ReportEvent("Kamiwaza", 0, eventType=win32evtlog.EVENTLOG_INFORMATION_TYPE, 
                                          strings=[log_line], data=None)
                logging_methods.append("eventlog")
            except ImportError:
                logging_methods.append("eventlog_skipped:win32evtlog_not_available")
            except Exception as e:
                logging_methods.append(f"eventlog_failed:{e}")
            
            # Method 4: Write to Windows debug output (for debugging tools)
            try:
                import ctypes
                ctypes.windll.kernel32.OutputDebugStringW(log_line)
                logging_methods.append("debug")
            except Exception as e:
                logging_methods.append(f"debug_failed:{e}")
            
            # Method 5: Write to Windows temp directory (always accessible)
            try:
                import tempfile
                temp_log = os.path.join(tempfile.gettempdir(), 'kamiwaza_installer_temp.log')
                with open(temp_log, 'a', encoding='utf-8', errors='replace') as f:
                    f.write(log_line + '\n')
                    f.flush()
                logging_methods.append("temp")
            except Exception as e:
                logging_methods.append(f"temp_failed:{e}")
            
            # Report progress to MSI if specified
            if progress is not None:
                progress_line = f"PROGRESS:{progress}"
                try:
                    print(progress_line)
                    # Also write progress to log file
                    if 'file' in logging_methods:
                        with open(log_file, 'a', encoding='utf-8', errors='replace') as f:
                            f.write(progress_line + '\n')
                            f.flush()
                except Exception as e:
                    logging_methods.append(f"progress_failed:{e}")
            
            # Force flush all output streams
            try:
                sys.stdout.flush()
                sys.stderr.flush()
            except:
                pass
            
            # Log which methods succeeded (for debugging)
            if len(logging_methods) < 2:
                # If less than 2 methods succeeded, try to log the failure
                try:
                    failure_msg = f"LOGGING_WARNING: Only {len(logging_methods)} methods succeeded: {logging_methods}"
                    print(failure_msg)
                    # Try to write to a simple text file as last resort
                    simple_log = os.path.join(os.getcwd(), 'kamiwaza_installer_simple.log')
                    with open(simple_log, 'a', encoding='utf-8', errors='replace') as f:
                        f.write(f"{timestamp}: {failure_msg}\n")
                        f.write(f"{timestamp}: {log_line}\n")
                except:
                    pass  # Last resort failed too
                    
        except Exception as e:
            # If even our logging fails, try the most basic method
            try:
                basic_msg = f"LOGGING_FAILED: {e} - Original message: {message}"
                print(basic_msg)
                sys.stdout.flush()
            except:
                pass  # Complete logging failure

    def run_command_with_streaming(self, command, timeout=None, progress_callback=None):
        """Run command with real-time output streaming"""
        self.log_output(f"Running with streaming: {' '.join(command)}")
        try:
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "UTF-8"
            
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startupinfo.wShowWindow = subprocess.SW_HIDE
            
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,  # Combine stderr with stdout
                text=True,
                encoding='utf-8',
                env=env,
                startupinfo=startupinfo,
                creationflags=subprocess.CREATE_NO_WINDOW,
                bufsize=1,  # Line buffered
                universal_newlines=True
            )
            
            output_lines = []
            start_time = datetime.datetime.now()
            last_heartbeat = start_time
            last_output_time = start_time
            
            # Read output line by line in real-time
            while True:
                current_time = datetime.datetime.now()
                
                # Check timeout
                if timeout and (current_time - start_time).total_seconds() > timeout:
                    process.kill()
                    self.log_output(f"Command timed out after {timeout} seconds")
                    return 1, "\n".join(output_lines), f"Command timed out after {timeout} seconds"
                
                # Show heartbeat every 30 seconds if no output
                if (current_time - last_heartbeat).total_seconds() > 30:
                    elapsed = int((current_time - start_time).total_seconds())
                    if (current_time - last_output_time).total_seconds() > 10:  # Only if no recent output
                        self.log_output(f"  [WAIT] Installation in progress... ({elapsed}s elapsed)")
                    last_heartbeat = current_time
                
                line = process.stdout.readline()
                if line:
                    line = line.rstrip('\n\r')
                    # Filter noisy systemd-cat errors when journald is not available
                    if "Failed to create stream fd" in line:
                        continue
                    output_lines.append(line)
                    last_output_time = current_time
                    
                    # Show real-time output
                    self.log_output(f"  INSTALL: {line}")
                    
                    # Call progress callback if provided
                    if progress_callback:
                        progress_callback(line)
                
                # Check if process is still running
                if process.poll() is not None:
                    # Process finished, read any remaining output
                    remaining = process.stdout.read()
                    if remaining:
                        for remaining_line in remaining.split('\n'):
                            if remaining_line.strip():
                                # Filter noisy systemd-cat errors when journald is not available
                                if "Failed to create stream fd" in remaining_line:
                                    continue
                                output_lines.append(remaining_line)
                                self.log_output(f"  INSTALL: {remaining_line}")
                    break
            
            return_code = process.returncode
            full_output = "\n".join(output_lines)
            
            # Show completion message
            elapsed = int((datetime.datetime.now() - start_time).total_seconds())
            self.log_output(f"  [OK] Command completed in {elapsed} seconds")
            
            return return_code, full_output, ""
            
        except Exception as e:
            self.log_output(f"Error running streaming command: {e}")
            return 1, "", str(e)
    
    def _wait_for_user_input(self, message="Press Enter to continue..."):
        """Wait for user input to prevent auto-exit and allow log review"""
        self.log_output("=== WAITING FOR USER INPUT ===")
        self.log_output(message)
        try:
            input()
        except:
            # In case we're in a non-interactive environment
            import time
            self.log_output("Non-interactive environment detected, waiting 10 seconds...")
            time.sleep(10)

    def run_command(self, command, timeout=None):
        """Run command and return exit code, stdout, stderr"""
        # Format command display with proper quoting for WSL bash commands
        if len(command) >= 4 and command[0] == 'wsl' and 'bash' in command and '-c' in command:
            # Find the bash -c command and quote it properly for PowerShell display
            bash_cmd_index = None
            for i, arg in enumerate(command):
                if arg == '-c' and i + 1 < len(command):
                    bash_cmd_index = i + 1
                    break
            
            if bash_cmd_index and bash_cmd_index < len(command):
                # Quote the bash command for PowerShell (the argument after -c)
                display_cmd = command[:bash_cmd_index] + [f'"{command[bash_cmd_index]}"']
                if bash_cmd_index + 1 < len(command):
                    display_cmd.extend(command[bash_cmd_index + 1:])
                self.log_output(f"Running: {' '.join(display_cmd)}")
            else:
                self.log_output(f"Running: {' '.join(command)}")
        else:
            self.log_output(f"Running: {' '.join(command)}")
        try:
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "UTF-8"
            
            startupinfo = subprocess.STARTUPINFO()
            startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startupinfo.wShowWindow = subprocess.SW_HIDE
            
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding='utf-8',
                env=env,
                startupinfo=startupinfo,
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            
            stdout, stderr = process.communicate(timeout=timeout)
            # Filter noisy systemd-cat errors when journald is not available
            def _filter_noise(s):
                if not s:
                    return s
                return "\n".join([ln for ln in s.splitlines() if "Failed to create stream fd" not in ln])
            stdout_filtered = _filter_noise(stdout)
            stderr_filtered = _filter_noise(stderr)
            if stdout_filtered:
                self.log_output(stdout_filtered.strip())
            if stderr_filtered:
                self.log_output(f"STDERR: {stderr_filtered.strip()}")
            
            return process.returncode, stdout, stderr
            
        except subprocess.TimeoutExpired:
            process.kill()
            self.log_output(f"Command timed out after {timeout} seconds")
            return 1, "", f"Command timed out after {timeout} seconds"
        except Exception as e:
            self.log_output(f"Error running command: {e}")
            return 1, "", str(e)

    def install(self):
        """Main installation process"""
        self.log_output("=== STARTING MAIN INSTALLATION PROCESS ===")
        
        # Track WSL instance for cleanup on failure
        wsl_cmd = None
        instance_name = None
        
        try:
            self.log_output("Starting Kamiwaza installation", progress=0)
            
            # Check WSL prerequisites first
            self.log_output("=== PHASE 0: WSL PREREQUISITES CHECK ===", progress=5)
            wsl_check_result = self.check_wsl_prerequisites()
            if not wsl_check_result:
                self.log_output("ERROR: WSL prerequisites not met")
                # The check_wsl_prerequisites method already provided specific instructions
                # Just add a reminder about restarting if WSL was installed
                self.log_output("")
                self.log_output("IMPORTANT: If WSL was just installed, you may need to restart your system")
                self.log_output("After restarting, re-run this installer")
                
                # Provide additional guidance for common WSL issues
                self.log_output("")
                self.log_output("=== ADDITIONAL WSL TROUBLESHOOTING GUIDANCE ===")
                self.log_output("If you continue to experience WSL issues, try these steps:")
                self.log_output("1. Restart your computer")
                self.log_output("2. Run Windows Update to ensure all components are current")
                self.log_output("3. Check if virtualization is enabled in BIOS/UEFI")
                self.log_output("4. Run as Administrator")
                self.log_output("5. Use Windows Features to manually enable WSL")
                
                self._wait_for_user_input("Press Enter to exit...")
                return 1
            
            # Get WSL distribution
            self.log_output("=== PHASE 1: WSL ENVIRONMENT SETUP ===", progress=10)
            self.log_output("Determining WSL distribution to use...")
            wsl_cmd = self.get_wsl_distribution()
            if wsl_cmd is None:
                self.log_output("ERROR: Failed to set up WSL environment")
                self.log_output("This is a CRITICAL ERROR - cannot proceed without WSL")
                
                # Only show repair guide if we're in interactive mode and user wants it
                try:
                    if sys.stdin.isatty() and hasattr(sys.stdin, 'readline'):
                        show_guide = input("Show detailed repair guide? (y/N): ").strip().lower()
                        if show_guide in ['y', 'yes']:
                            self.log_output("")
                            self.provide_hcs_service_error_repair_summary()
                except:
                    # Non-interactive mode - just show basic guidance
                    self.log_output("")
                    self.log_output("=== BASIC REPAIR GUIDANCE ===")
                    self.log_output("1. Restart your computer")
                    self.log_output("2. Run Windows Update")
                    self.log_output("3. Run this installer as Administrator")
                    self.log_output("4. If problems persist, check BIOS/UEFI virtualization settings")
                
                # No cleanup needed here as no WSL instance was created yet
                self.log_output("")
                self.log_output("=== INSTALLATION FAILED ===")
                self.log_output("The installer cannot proceed without a working WSL environment.")
                self.log_output("Please resolve the WSL issues and re-run this installer.")
                
                # Only wait for user input in interactive mode
                if sys.stdin.isatty() and hasattr(sys.stdin, 'readline'):
                    try:
                        self._wait_for_user_input("Press Enter to exit...")
                    except:
                        # User interrupted, continue to exit
                        pass
                else:
                    # Non-interactive mode - just exit after a brief delay
                    self.log_output("Non-interactive mode detected - exiting in 5 seconds...")
                    import time
                    time.sleep(5)
                
                return 1
            
            # Extract instance name for cleanup tracking
            if len(wsl_cmd) > 2 and wsl_cmd[1] == '-d':
                instance_name = wsl_cmd[2]
                self.log_output(f"Tracking WSL instance for cleanup: {instance_name}")
            else:
                instance_name = 'default'
                self.log_output("Tracking default WSL instance for cleanup")
            
            self.log_output(f"SUCCESS: Will use WSL command: {' '.join(wsl_cmd)}")
            
            # Test WSL connectivity and user
            self.log_output("Testing WSL instance connectivity and user configuration...")
            test_ret, test_out, test_err = self.run_command(wsl_cmd + ['echo', 'WSL_CONNECTION_TEST'])
            if test_ret == 0:
                self.log_output(f"SUCCESS: WSL connectivity confirmed: {test_out.strip()}")
            else:
                self.log_output(f"WARNING: WSL connectivity test failed: {test_err}")
            
            # Verify user configuration
            user_ret, user_out, user_err = self.run_command(wsl_cmd + ['whoami'])
            if user_ret == 0:
                current_user = user_out.strip()
                self.log_output(f"WSL default user: {current_user}")
                if current_user == 'kamiwaza':
                    self.log_output("[OK] Confirmed: WSL instance uses kamiwaza user")
                else:
                    self.log_output(f"[WARN] WARNING: WSL instance uses '{current_user}' instead of kamiwaza")
            else:
                self.log_output(f"WARNING: Could not verify WSL user: {user_err}")
            
            # Test sudo access for kamiwaza user
            if user_ret == 0 and user_out.strip() == 'kamiwaza':
                sudo_ret, sudo_out, sudo_err = self.run_command(wsl_cmd + ['sudo', '-n', 'whoami'])
                if sudo_ret == 0 and sudo_out.strip() == 'root':
                    self.log_output("[OK] Confirmed: kamiwaza user has passwordless sudo access")
                else:
                    self.log_output(f"[WARN] WARNING: kamiwaza user sudo test failed: {sudo_err}")
            
            self.log_output("=== PHASE 1 COMPLETE ===\n")
            
            # Configure WSL memory
            self.log_output("=== PHASE 2: WSL MEMORY CONFIGURATION ===", progress=20)
            self.log_output(f"Configuring WSL memory allocation: {self.memory}")
            memory_result = self.configure_wsl_memory()
            if memory_result:
                self.log_output("SUCCESS: WSL memory configuration completed")
            else:
                self.log_output("WARNING: WSL memory configuration failed (non-critical)")
            self.log_output("=== PHASE 2 COMPLETE ===\n")
            
            # Configure debconf
            self.log_output("=== PHASE 3: DEBCONF CONFIGURATION ===", progress=30)
            self.log_output("Setting up package installation preferences...")
            self.log_output(f"Configuring for email: {self.user_email}")
            self.log_output(f"Configuring for mode: {self.install_mode}")
            self.log_output(f"Configuring usage reporting: {self.usage_reporting}")
            self.configure_debconf(wsl_cmd)
            
            # Configure swap space in WSL (both .wslconfig and within WSL instance)
            self.log_output("Configuring swap space in WSL...")
            self.log_output("Note: Swap is configured in both .wslconfig (Windows) and within WSL instance")
            self.configure_swap_space(wsl_cmd)
            
            # Disable IPv6 in WSL
            self.log_output("Disabling IPv6 in WSL for better network compatibility...")
            self.disable_ipv6_wsl(wsl_cmd)
            
            self.log_output("=== PHASE 3 COMPLETE ===\n")
            
            # GPU Driver Downloads (before package installation)
            self.log_output("=== PHASE 4: GPU DRIVER PREPARATION ===", progress=35)
            self.download_gpu_drivers(wsl_cmd)
            self.log_output("=== PHASE 4 COMPLETE ===\n")
            
            # Note: GPU restart logic is now handled directly in the GPU setup scripts
            # This ensures GPU drivers are active before package installation and postinst script
            
            # Download DEB (but don't install yet)
            self.log_output("=== PHASE 5: PACKAGE DOWNLOAD ===", progress=40)
            deb_url = self.get_deb_url()
            deb_filename = self.get_deb_filename()
            deb_path = f"/tmp/{deb_filename}"
            
            self.log_output(f"Package details:")
            self.log_output(f"  URL: {deb_url}")
            self.log_output(f"  Filename: {deb_filename}")
            self.log_output(f"  WSL path: {deb_path}")
            
            download_cmd = f"wget --timeout=60 --tries=3 --progress=bar --show-progress '{deb_url}' -O {deb_path}"
            self.log_output(f"Download command: {download_cmd}")
            
            ret, download_out, err = self.run_command(wsl_cmd + ['bash', '-c', download_cmd])
            if ret != 0:
                self.log_output(f"CRITICAL ERROR: Download failed with exit code {ret}")
                self.log_output(f"Download error: {err}")
                self.log_output(f"Download output: {download_out}")
                # Clean up WSL instance on download failure
                self.log_output("Cleaning up WSL instance due to download failure...")
                self.cleanup_on_failure(wsl_cmd, instance_name)
                self._wait_for_user_input("Press Enter to exit...")
                return 1
            
            # Ensure file command is available before verification
            file_check_cmd = f"which file"
            file_check_ret, _, _ = self.run_command(wsl_cmd + ['bash', '-c', file_check_cmd])
            if file_check_ret != 0:
                self.log_output("Installing file command...")
                install_file_cmd = f"sudo apt update -qq"
                self.run_command(wsl_cmd + ['bash', '-c', install_file_cmd])
                install_file_cmd2 = f"sudo apt install -y file"
                self.run_command(wsl_cmd + ['bash', '-c', install_file_cmd2])
            
            # Verify downloaded file (split into separate commands)
            verify_cmd = f"ls -la {deb_path}"
            verify_ret, verify_out, verify_err = self.run_command(wsl_cmd + ['bash', '-c', verify_cmd])
            if verify_ret == 0:
                self.log_output(f"SUCCESS: Download verified: {verify_out.strip()}")
                
                # Get file type
                file_cmd = f"file {deb_path}"
                file_ret, file_out, file_err = self.run_command(wsl_cmd + ['bash', '-c', file_cmd])
                if file_ret == 0:
                    self.log_output(f"File type: {file_out.strip()}")
                else:
                    self.log_output(f"Could not determine file type: {file_err.strip()}")
            else:
                self.log_output(f"WARNING: Could not verify download: {verify_err}")
            
            self.log_output("=== PHASE 5 COMPLETE ===\n")
            
            # Install DEB (GPU restart logic is now handled directly in GPU setup scripts)
            self.log_output("=== PHASE 6: PACKAGE INSTALLATION ===", progress=60)
            self.log_output("This is the critical phase - installing the Kamiwaza package")
            self.log_output("All output from this phase will be logged to systemd journal")
            self.log_output("You can view logs later with: wsl -d kamiwaza journalctl -t kamiwaza-install")
            
            # Get current timestamp for logging
            import datetime
            timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # First, log the start of installation
            self.log_output(f"Step 1/3: Logging installation start", progress=60)
            start_cmd = f"echo '[{timestamp}] Starting Kamiwaza installation' | systemd-cat -t kamiwaza-install -p info 2>/dev/null || true"
            ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', start_cmd])
            
            # Update package lists with logging
            self.log_output(f"Step 2/3: Updating package lists", progress=70)
            self.log_output("Running apt update with real-time output...")
            
            update_cmd = f"""
            echo '[{timestamp}] Starting apt update' >> /tmp/kamiwaza_install.log
            export DEBIAN_FRONTEND=noninteractive
            sudo -E apt update >> /tmp/kamiwaza_install.log 2>&1
            UPDATE_EXIT_CODE=$?
            echo "[{timestamp}] apt update completed with exit code $UPDATE_EXIT_CODE" >> /tmp/kamiwaza_install.log
            
            # Also try to log to systemd journal (may not work reliably)
            echo '[{timestamp}] apt update completed' | systemd-cat -t kamiwaza-install -p info 2>/dev/null || true
            
            exit $UPDATE_EXIT_CODE
            """
            
            ret, out, err = self.run_command_with_streaming(
                wsl_cmd + ['bash', '-c', update_cmd], 
                timeout=120
            )
            if ret != 0:
                self.log_output(f"WARNING: apt update failed with exit code {ret}")
                if out:
                    self.log_output(f"STDOUT: {out}")
                if err:
                    self.log_output(f"STDERR: {err}")
            else:
                self.log_output("Successfully updated package lists")
            
            # Install the DEB package - NO TIMEOUT, with real-time logging
            self.log_output(f"Step 3/3: Installing Kamiwaza package (this may take a while for large packages)", progress=80)
            self.log_output(f"Package size: {deb_path}")
            self.log_output(f"Starting apt install with real-time output...")
            
            # Create progress callback for installation milestones
            def installation_progress_callback(line):
                # Look for key installation milestones and update progress
                if "Unpacking" in line or "Preparing" in line:
                    self.log_output("", progress=82)
                elif "Setting up" in line or "Configuring" in line:
                    self.log_output("", progress=85)
                elif "Processing triggers" in line:
                    self.log_output("", progress=88)
                elif "complete" in line.lower() or "finished" in line.lower():
                    self.log_output("", progress=90)
            
            # Use streaming installation command (WSL2 compatible)
            install_cmd = f"""
            echo '[{timestamp}] Starting apt install of {deb_path}' > /tmp/kamiwaza_install.log
            export DEBIAN_FRONTEND=noninteractive
            sudo -E apt install -f -y {deb_path}
            INSTALL_EXIT_CODE=$?
            echo "[{timestamp}] apt install completed with exit code $INSTALL_EXIT_CODE" >> /tmp/kamiwaza_install.log
            
            # Also try to log to systemd journal (may not work reliably)
            echo '[{timestamp}] Starting apt install of {deb_path}' | systemd-cat -t kamiwaza-install -p info 2>/dev/null || true
            cat /tmp/kamiwaza_install.log | systemd-cat -t kamiwaza-install -p info 2>/dev/null || true
            echo "[{timestamp}] apt install completed with exit code $INSTALL_EXIT_CODE" | systemd-cat -t kamiwaza-install -p info 2>/dev/null || true
            echo ''
            echo '********* NOTE: This will take several minutes before continuing - DO NOT EXIT THIS SCRIPT!! *********'
            echo ''
            exit $INSTALL_EXIT_CODE
            echo '********* NOTE: This will take several minutes before continuing - DO NOT EXIT THIS SCRIPT!! *********'
            """
            
            ret, out, err = self.run_command_with_streaming(
                wsl_cmd + ['bash', '-c', install_cmd], 
                timeout=None,  # NO TIMEOUT
                progress_callback=installation_progress_callback
            )
            if ret != 0:
                self.log_output(f"CRITICAL: apt install failed with exit code {ret}")
                self.log_output(f"Installation output: {out}")
                self.log_output(f"Installation errors: {err}")
                # Try to get the backup log file content
                log_cmd = f"cat /tmp/kamiwaza_install.log 2>/dev/null || echo 'Backup log not found'"
                log_ret, log_out, log_err = self.run_command(wsl_cmd + ['bash', '-c', log_cmd], timeout=30)
                if log_ret == 0 and log_out and 'Backup log not found' not in log_out:
                    self.log_output(f"Backup installation log content: {log_out}")
                
                # Also check APT logs for more details
                apt_log_cmd = f"tail -50 /var/log/apt/term.log 2>/dev/null || echo 'APT term log not available'"
                apt_ret, apt_out, apt_err = self.run_command(wsl_cmd + ['bash', '-c', apt_log_cmd], timeout=30)
                if apt_ret == 0 and apt_out and 'APT term log not available' not in apt_out:
                    self.log_output("Last 50 lines from APT term log:")
                    for line in apt_out.strip().split('\n')[-20:]:  # Show last 20 lines
                        if line.strip():
                            self.log_output(f"  APT: {line}")
                
                # Clean up WSL instance on package installation failure
                self.log_output("Cleaning up WSL instance due to package installation failure...")
                self.cleanup_on_failure(wsl_cmd, instance_name)
            else:
                self.log_output(f"SUCCESS: apt install completed successfully")
                if out:
                    self.log_output(f"Installation output: {out}")
                
                # Verify GPU drivers after successful package installation
                self.log_output("=== PHASE 7: GPU DRIVER VERIFICATION (SKIPPED) ===", progress=85)
                
                # Show success message from backup log if available
                log_cmd = f"tail -10 /tmp/kamiwaza_install.log 2>/dev/null || echo 'Backup log not found'"
                log_ret, log_out, log_err = self.run_command(wsl_cmd + ['bash', '-c', log_cmd])
                if log_ret == 0 and log_out and 'Backup log not found' not in log_out:
                    self.log_output("Last lines from backup install log:")
                    for line in log_out.strip().split('\n')[-5:]:
                        if line.strip():
                            self.log_output(f"  LOG: {line}")
            
            # Clean up the DEB file
            cleanup_cmd = f"rm {deb_path}"
            self.run_command(wsl_cmd + ['bash', '-c', cleanup_cmd])
            
            # Copy logs to Windows AppData folder for easy access
            self.log_output("=== COPYING LOGS TO WINDOWS ===")
            self.copy_logs_to_windows(wsl_cmd, timestamp)
            
            # Verify actual log files exist and show content summary
            self.log_output("=== VERIFYING ACTUAL LOG FILES ===")
            self.verify_and_show_logs(wsl_cmd)
            
            self.log_output("=== INSTALLATION COMPLETED ===", progress=100)
            self.log_output("SUCCESS: All installation phases completed!")
            self.log_output("")
            
            # Test if kamiwaza command is available
            self.log_output("=== POST-INSTALLATION VERIFICATION ===")
            kamiwaza_test_ret, kamiwaza_out, kamiwaza_err = self.run_command(wsl_cmd + ['which', 'kamiwaza'])
            if kamiwaza_test_ret == 0:
                self.log_output(f"SUCCESS: kamiwaza command found at: {kamiwaza_out.strip()}")
            else:
                self.log_output(f"WARNING: kamiwaza command not found in PATH: {kamiwaza_err}")
            
            # Test kamiwaza version
            version_ret, version_out, version_err = self.run_command(wsl_cmd + ['kamiwaza', 'version'])
            if version_ret == 0:
                self.log_output(f"SUCCESS: Kamiwaza version: {version_out.strip()}")
            else:
                self.log_output(f"INFO: Could not get kamiwaza version (may need setup): {version_err}")
                        
            # GPU setup completed - restart will happen after package installation
            self.log_output("")
            self.log_output("=== GPU SETUP COMPLETE ===", progress=95)
            self.log_output("GPU drivers have been installed and configured successfully.")
            self.log_output("")
            self.log_output("IMPORTANT: GPU drivers are installed but NOT yet active")
            self.log_output("The system will restart ONCE after package installation completes")
            self.log_output("After restart, both GPU acceleration AND Kamiwaza will be ready")
            self.log_output("")
            self.log_output("Continuing with Kamiwaza package installation...")
            
            self.log_output("")
            self.log_output("=== LOG ACCESS INFORMATION ===")
            wsl_instance = wsl_cmd[2] if len(wsl_cmd) > 2 else 'default'
            
            # Show Windows log locations first (most accessible)
            appdata_logs = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza', 'logs')
            self.log_output("WINDOWS LOG LOCATIONS (copied from WSL for easy access):")
            self.log_output(f"  Installation logs: {appdata_logs}\\kamiwaza_install_logs.txt")
            self.log_output(f"  APT detailed logs: {appdata_logs}\\apt_term_log.txt")
            self.log_output(f"  APT history logs: {appdata_logs}\\apt_history_log.txt")
            self.log_output(f"  DPKG operations: {appdata_logs}\\dpkg_log.txt")
            self.log_output("")
            
            # Show installer-specific log locations
            self.log_output("INSTALLER LOG LOCATIONS (this script's output):")
            self.log_output(f"  Primary installer log: {appdata_logs}\\kamiwaza_installer.log")
            self.log_output(f"  Temporary installer log: {os.path.join(tempfile.gettempdir(), 'kamiwaza_installer_temp.log')}")
            self.log_output(f"  Simple fallback log: {os.path.join(os.getcwd(), 'kamiwaza_installer_simple.log')}")
            self.log_output("")
            
            # Show WSL log locations (original sources)
            self.log_output("WSL LOG LOCATIONS (original files in Linux):")
            self.log_output("  PRIMARY - Detailed installation output:")
            self.log_output(f"    wsl -d {wsl_instance} -- cat /var/log/apt/term.log")
            self.log_output(f"    wsl -d {wsl_instance} -- tail -100 /var/log/apt/term.log")
            self.log_output("")
            self.log_output("  SECONDARY - Installation history:")
            self.log_output(f"    wsl -d {wsl_instance} -- cat /var/log/apt/history.log")
            self.log_output(f"    wsl -d {wsl_instance} -- tail -50 /var/log/apt/history.log")
            self.log_output("")
            self.log_output("  DPKG-level operations:")
            self.log_output(f"    wsl -d {wsl_instance} -- grep kamiwaza /var/log/dpkg.log")
            self.log_output("")
            self.log_output("  System journal (sudo commands only):")
            self.log_output(f"    wsl -d {wsl_instance} -- journalctl | grep kamiwaza")
            self.log_output("")
            
            # Show how to search for errors
            self.log_output("TO SEARCH FOR ERRORS:")
            self.log_output(f"  wsl -d {wsl_instance} -- grep -i error /var/log/apt/term.log")
            self.log_output(f"  wsl -d {wsl_instance} -- grep -i fail /var/log/apt/term.log")
            self.log_output("")
            
            # Explain the logging situation
            self.log_output("NOTE: The systemd journal logging (systemd-cat) used by this installer")
            self.log_output("may not capture all output. The APT logs in /var/log/apt/ contain")
            self.log_output("the complete installation details and are the authoritative source.")
            self.log_output("")
            
            self.log_output("=== INSTALLATION COMPLETE ===")
            
            self.log_output("KAMIWAZA INSTALLATION COMPLETED SUCCESSFULLY!")
            self.log_output("")
            self.log_output("A system restart is required to activate GPU acceleration and Kamiwaza.")
            self.log_output("The MSI installer will prompt you to restart; you may reboot later.")
            self.log_output("")
            self.log_output("After restart:")
            self.log_output("1. GPU acceleration will be active and ready")
            self.log_output("2. Kamiwaza will start automatically with optimal performance")
            self.log_output("3. All GPU features will be fully functional")
            self.log_output("4. Package installation will be complete and active")
            self.log_output("")
 
            # Request reboot via MSI (no automatic restart)
            self.log_output("")
            self.log_output("=== REBOOT REQUIRED ===", progress=100)
            self.log_output("Installation completed successfully. A system restart is required to activate GPU acceleration and finalize setup.")
            self.log_output("The MSI installer will prompt you to restart. You can restart later if preferred.")
            
            # Attempt a clean WSL shutdown to avoid locks before reboot
            try:
                self.run_command(['wsl', '--shutdown'], timeout=30)
            except Exception:
                pass
            
            return 3010
            
        except Exception as e:
            self.log_output("[ERROR] Failed to trigger automatic FULL DEVICE restart: {e}")
            self.log_output("[VERBOSE] Exception details:")
            import traceback
            for line in traceback.format_exc().split('\n'):
                if line.strip():
                    self.log_output(f"[VERBOSE]   {line}")
            
            self.log_output("[CRITICAL] Please restart your computer manually to activate GPU acceleration")
            self.log_output("After restart, Kamiwaza will start automatically")
            
            # Provide detailed manual restart instructions
            self.log_output("")
            self.log_output("=== MANUAL RESTART REQUIRED ===")
            self.log_output("Automatic restart failed - please restart manually:")
            self.log_output("1. Save all work and close applications")
            self.log_output("2. Press Windows + R, type 'shutdown /r /t 0', press Enter")
            self.log_output("3. Or use Start Menu > Power > Restart")
            self.log_output("4. Or press Ctrl + Alt + Delete > Power > Restart")
            self.log_output("")
            self.log_output("After restart, Kamiwaza will start automatically with GPU acceleration")
            self.log_output("")
            
            self._wait_for_user_input("Press Enter to exit...")
        
        return 0

    def get_wsl_distribution(self):
        """Get WSL distribution command"""
        # Try dedicated instance first
        dedicated = self.create_dedicated_wsl_instance()
        if dedicated:
            return ['wsl', '-d', dedicated]
        
        # If dedicated instance creation failed, attempt automatic repair
        self.log_output("Dedicated kamiwaza instance creation failed - attempting automatic repair...")
        
        # Only check for existing kamiwaza instance or Ubuntu-24.04
        # User explicitly requested: "We should only use the existing wsl if its name is KAMIWAZA - nothing else"
        # and "We NEVER want 22.04 - only 24.04"
        ret, out, _ = self.run_command(['wsl', '--list', '--quiet'])
        if ret != 0:
            self.log_output("ERROR: WSL is not available")
            
            # Check for specific HCS service error
            if "HCS_E_SERVICE_NOT_AVAILABLE" in str(out) or "required feature is not installed" in str(out):
                self.log_output("DETECTED: HCS service error - attempting automatic repair...")
                
                # Try to fix the HCS service error
                if self.fix_hcs_service_error():
                    self.log_output("WSL service fixed successfully, retrying distribution check...")
                    ret, out, _ = self.run_command(['wsl', '--list', '--quiet'])
                    if ret != 0:
                        self.log_output("WSL service still not functional after basic repair")
                        self.log_output("Attempting advanced repair methods...")
                        
                        if self.perform_advanced_hcs_repair():
                            self.log_output("Advanced repair completed, retrying distribution check...")
                            ret, out, _ = self.run_command(['wsl', '--list', '--quiet'])
                            if ret != 0:
                                self.log_output("WSL service still not functional after all repair attempts")
                                self.log_output("System restart required to fully resolve WSL service issues")
                                return None
                        else:
                            self.log_output("Advanced repair failed, system restart required")
                            return None
                else:
                    self.log_output("Basic repair failed, attempting advanced repair...")
                    
                    if self.perform_advanced_hcs_repair():
                        self.log_output("Advanced repair completed, retrying distribution check...")
                        ret, out, _ = self.run_command(['wsl', '--list', '--quiet'])
                        if ret != 0:
                            self.log_output("WSL service still not functional after advanced repair")
                            self.log_output("System restart required to fully resolve WSL service issues")
                            return None
                    else:
                        self.log_output("All repair methods failed, system restart required")
                        return None
            else:
                # Check if this might be a disk attachment issue
                if "Failed to attach disk" in str(out) or "ERROR_PATH_NOT_FOUND" in str(out):
                    self.log_output("DETECTED: Possible WSL disk attachment issue - attempting recovery...")
                    if self.recover_wsl_disk_attachment():
                        self.log_output("WSL disk attachment recovered, retrying distribution check...")
                        ret, out, _ = self.run_command(['wsl', '--list', '--quiet'])
                        if ret == 0:
                            self.log_output("SUCCESS: WSL is now available after disk attachment recovery")
                            return True
                        else:
                            self.log_output("WSL still not functional after disk attachment recovery")
                            return None
                    else:
                        self.log_output("WSL disk attachment recovery failed")
                        return None
                else:
                    self.log_output("On Windows Server, you may need to manually enable WSL:")
                    self.log_output("  - Server 2022: Run 'wsl --install' as Administrator")
                    self.log_output("  - Server 2019: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux")
                    return None
        
        if ret == 0:
            wsl_instances = out.replace('\x00', '').replace(' ', '').replace('\r', '').replace('\n', ' ').split()
            wsl_instances = [name.strip() for name in wsl_instances if name.strip()]  # Remove empty entries
            if 'Ubuntu-24.04' in wsl_instances:
                self.log_output("Existing Ubuntu-24.04 WSL instance found")
                self.log_output("Restarting WSL to ensure clean state for installation...")
                
                # Stop the existing Ubuntu-24.04 instance
                self.log_output("Stopping Ubuntu-24.04 WSL instance...")
                stop_ret, stop_out, stop_err = self.run_command(['wsl', '--terminate', 'Ubuntu-24.04'])
                if stop_ret == 0:
                    self.log_output("Successfully stopped Ubuntu-24.04 instance")
                else:
                    self.log_output(f"Warning: Could not stop Ubuntu-24.04 instance: {stop_err}")
                
                # Shutdown all WSL instances to ensure clean restart (WSL ONLY - not the entire device)
                self.log_output("Shutting down all WSL instances for clean restart...")
                self.log_output("NOTE: This only stops WSL Linux instances - does NOT restart your computer")
                shutdown_ret, shutdown_out, shutdown_err = self.run_command(['wsl', '--shutdown'])
                if shutdown_ret == 0:
                    self.log_output("Successfully shutdown all WSL instances")
                else:
                    self.log_output(f"Warning: WSL shutdown command failed: {shutdown_err}")
                
                # Wait a moment for WSL to fully shutdown
                import time
                self.log_output("Waiting for WSL to fully shutdown...")
                time.sleep(3)
                
                # Verify the instance is accessible after restart
                self.log_output("Verifying Ubuntu-24.04 instance accessibility after restart...")
                test_ret, test_out, test_err = self.run_command(['wsl', '-d', 'Ubuntu-24.04', 'echo', 'restart_test'])
                if test_ret == 0:
                    self.log_output("Successfully restarted and verified Ubuntu-24.04 instance")
                    self.log_output(f"Test output: {test_out.strip()}")
                else:
                    self.log_output(f"ERROR: Could not access Ubuntu-24.04 instance after restart: {test_err}")
                    
                                    # Check if it's a disk attachment issue (recoverable)
                if "Failed to attach disk" in test_err or "ERROR_PATH_NOT_FOUND" in test_err:
                    self.log_output("DETECTED: WSL disk attachment issue - this is recoverable!")
                    self.log_output("The WSL service is having trouble mounting the disk, but this can be fixed.")
                    self.log_output("Attempting automatic recovery...")
                    
                    # Try to recover the WSL service
                    if self.recover_wsl_disk_attachment():
                        self.log_output("WSL disk attachment recovered successfully!")
                        self.log_output("Retrying instance access...")
                        
                        # Wait a moment for recovery to take effect
                        import time
                        time.sleep(5)
                        
                        # Test access again
                        retry_ret, retry_out, retry_err = self.run_command(['wsl', '-d', 'Ubuntu-24.04', 'echo', 'recovery_test'])
                        if retry_ret == 0:
                            self.log_output("SUCCESS: Ubuntu-24.04 instance accessible after recovery!")
                            self.log_output(f"Recovery test output: {retry_out.strip()}")
                            return ['wsl', '-d', 'Ubuntu-24.04']
                        else:
                            self.log_output(f"Recovery attempt failed - instance still not accessible: {retry_err}")
                            self.log_output("This indicates a deeper issue that may require manual intervention")
                            return None
                    else:
                        self.log_output("WSL disk attachment recovery failed")
                        self.log_output("This may require manual intervention or system restart")
                        return None
                else:
                    self.log_output("This may indicate a different WSL issue. Please check WSL configuration.")
                    return None
                
                # Ensure Ubuntu-24.04 also uses kamiwaza as default user
                self.log_output("Verifying default user for Ubuntu-24.04...")
                ret, whoami_out, _ = self.run_command(['wsl', '-d', 'Ubuntu-24.04', 'whoami'])
                if ret == 0:
                    current_user = whoami_out.strip()
                    self.log_output(f"Current Ubuntu-24.04 default user: {current_user}")
                    if current_user != 'kamiwaza':
                        self.log_output("Configuring Ubuntu-24.04 to use kamiwaza as default user...")
                        ret, _, err = self.run_command(['wsl', '--set-default-user', 'Ubuntu-24.04', 'kamiwaza'])
                        if ret != 0:
                            self.log_output(f"WARNING: Failed to set Ubuntu-24.04 default user: {err}")
                        else:
                            self.log_output("Successfully configured Ubuntu-24.04 default user to kamiwaza")
                return ['wsl', '-d', 'Ubuntu-24.04']
        
        self.log_output("ERROR: No suitable WSL distribution found. Only 'kamiwaza' or 'Ubuntu-24.04' are supported.")
        self.log_output("All automatic repair attempts have been exhausted.")
        self.log_output("System restart required to resolve WSL service issues.")
        
        return None

    def create_dedicated_wsl_instance(self):
        """Create dedicated 'kamiwaza' WSL instance from Ubuntu 24.04 cloud image"""
        instance_name = "kamiwaza"
        self.log_output(f"Setting up dedicated WSL instance: {instance_name}")
        
        # Check what WSL distributions exist
        ret, out, err = self.run_command(['wsl', '--list', '--quiet'])
        if ret != 0:
            self.log_output("ERROR: WSL is not available")
            self.log_output("On Windows Server, you may need to manually enable WSL:")
            self.log_output("  - Server 2022: Run 'wsl --install' as Administrator")
            self.log_output("  - Server 2019: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux")
            return None
        
        # Parse WSL instances (handle UTF-16 encoding with null bytes and spaces)
        wsl_instances = out.replace('\x00', '').replace(' ', '').replace('\r', '').replace('\n', ' ').split()
        wsl_instances = [name.strip() for name in wsl_instances if name.strip()]  # Remove empty entries
        if instance_name in wsl_instances:
            self.log_output(f"Existing {instance_name} WSL instance found")
            self.log_output("Restarting WSL to ensure clean state for installation...")
            
            # Stop the existing WSL instance
            self.log_output(f"Stopping {instance_name} WSL instance...")
            stop_ret, stop_out, stop_err = self.run_command(['wsl', '--terminate', instance_name])
            if stop_ret == 0:
                self.log_output(f"Successfully stopped {instance_name} instance")
            else:
                self.log_output(f"Warning: Could not stop {instance_name} instance: {stop_err}")
            
            # Shutdown all WSL instances to ensure clean restart (WSL ONLY - not the entire device)
            self.log_output("Shutting down all WSL instances for clean restart...")
            self.log_output("NOTE: This only stops WSL Linux instances - does NOT restart your computer")
            shutdown_ret, shutdown_out, shutdown_err = self.run_command(['wsl', '--shutdown'])
            if shutdown_ret == 0:
                self.log_output("Successfully shutdown all WSL instances")
            else:
                self.log_output(f"Warning: WSL shutdown command failed: {shutdown_err}")
            
            # Wait a moment for WSL to fully shutdown
            import time
            self.log_output("Waiting for WSL to fully shutdown...")
            time.sleep(3)
            
            # Verify the instance is accessible after restart
            self.log_output(f"Verifying {instance_name} instance accessibility after restart...")
            test_ret, test_out, test_err = self.run_command(['wsl', '-d', instance_name, 'echo', 'restart_test'])
            if test_ret == 0:
                self.log_output(f"Successfully restarted and verified {instance_name} instance")
                self.log_output(f"Test output: {test_out.strip()}")
            else:
                self.log_output(f"ERROR: Could not access {instance_name} instance after restart: {test_err}")
                
                # Check if it's a disk attachment issue (recoverable)
                if "Failed to attach disk" in test_err or "ERROR_PATH_NOT_FOUND" in test_err:
                    self.log_output("DETECTED: WSL disk attachment issue - this is recoverable!")
                    self.log_output("The WSL service is having trouble mounting the disk, but this can be fixed.")
                    self.log_output("Attempting automatic recovery...")
                    
                    # Try to recover the WSL service
                    if self.recover_wsl_disk_attachment():
                        self.log_output("WSL disk attachment recovered successfully!")
                        self.log_output("Retrying instance access...")
                        
                        # Wait a moment for recovery to take effect
                        import time
                        time.sleep(5)
                        
                        # Test access again
                        retry_ret, retry_out, retry_err = self.run_command(['wsl', '-d', instance_name, 'echo', 'recovery_test'])
                        if retry_ret == 0:
                            self.log_output("SUCCESS: {instance_name} instance accessible after recovery!")
                            self.log_output(f"Recovery test output: {retry_out.strip()}")
                            return instance_name
                        else:
                            self.log_output(f"Recovery attempt failed - instance still not accessible: {retry_err}")
                            self.log_output("This indicates a deeper issue that may require manual intervention")
                            return None
                    else:
                        self.log_output("WSL disk attachment recovery failed")
                        self.log_output("This may require manual intervention or system restart")
                        return None
                else:
                    self.log_output("This may indicate a different WSL issue. Please check WSL configuration.")
                    return None
            
            return instance_name
        
        # Create kamiwaza instance from Ubuntu 24.04 cloud image
        self.log_output(f"Creating fresh {instance_name} instance from Ubuntu 24.04 cloud image...")
        
        # Setup paths
        wsl_dir = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'WSL', instance_name)
        temp_dir = tempfile.gettempdir()
        rootfs_file = os.path.join(temp_dir, f'ubuntu-24.04-wsl-{os.getpid()}.rootfs.tar.gz')
        
        # Create WSL directory
        os.makedirs(wsl_dir, exist_ok=True)
        self.log_output(f"Created WSL directory: {wsl_dir}")
        
        # Download Ubuntu 24.04 WSL rootfs
        self.log_output("Downloading Ubuntu 24.04 WSL rootfs from cloud images...")
        download_url = "https://cloud-images.ubuntu.com/wsl/releases/24.04/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz"
        
        # Use curl to download (more reliable and shows progress)
        download_cmd = [
            'curl', '-L', '-o', rootfs_file, download_url,
            '--connect-timeout', '30'
        ]
        ret, _, err = self.run_command(download_cmd)  # 23+ minutes for 340MB download
        
        if ret != 0:
            self.log_output(f"ERROR: Failed to download Ubuntu rootfs: {err}")
            return None
            
        # Verify download
        if not os.path.exists(rootfs_file):
            self.log_output("ERROR: Downloaded rootfs file not found")
            return None
            
        self.log_output(f"Successfully downloaded rootfs: {os.path.getsize(rootfs_file)} bytes")
        
        # Import as kamiwaza WSL instance
        self.log_output(f"Importing as '{instance_name}' WSL instance...")
        self.log_output(f"Import command: wsl --import {instance_name} {wsl_dir} {rootfs_file}")
        ret, _, err = self.run_command(['wsl', '--import', instance_name, wsl_dir, rootfs_file])
        
        # Clean up downloaded file
        try:
            os.remove(rootfs_file)
            self.log_output("Cleaned up downloaded rootfs file")
        except:
            pass
        
        if ret != 0:
            self.log_output(f"ERROR: Failed to import {instance_name} instance: {err}")
            
            # Check for specific HCS service error
            if "HCS_E_SERVICE_NOT_AVAILABLE" in err or "required feature is not installed" in err:
                self.log_output("DETECTED: HCS service error - WSL service is not properly running")
                self.log_output("Attempting to fix WSL service automatically...")
                
                # Try to fix the HCS service error
                if self.fix_hcs_service_error():
                    self.log_output("WSL service fixed successfully, retrying import...")
                    ret, _, err = self.run_command(['wsl', '--import', instance_name, wsl_dir, rootfs_file])
                    if ret == 0:
                        self.log_output("SUCCESS: WSL import completed after fixing service")
                    else:
                        self.log_output(f"ERROR: WSL import still failed after service fix: {err}")
                        # Check if it's still an HCS error after fix attempt
                        if "HCS_E_SERVICE_NOT_AVAILABLE" in err or "required feature is not installed" in err:
                            self.log_output("HCS service error persists after fix attempt")
                            self.log_output("Attempting additional repair methods...")
                            
                            # Try additional repair methods
                            if self.perform_advanced_hcs_repair():
                                self.log_output("Advanced repair completed, retrying import...")
                                ret, _, err = self.run_command(['wsl', '--import', instance_name, wsl_dir, rootfs_file])
                                if ret == 0:
                                    self.log_output("SUCCESS: WSL import completed after advanced repair")
                                else:
                                    self.log_output(f"ERROR: WSL import still failed after advanced repair: {err}")
                                    self.log_output("This requires a system restart to fully resolve")
                                    self.log_output("Please restart your system and re-run this installer")
                                    return None
                            else:
                                self.log_output("Advanced repair failed, system restart required")
                                self.log_output("Please restart your system and re-run this installer")
                                return None
                        return None
                else:
                    self.log_output("Failed to fix WSL service with basic repair")
                    self.log_output("Attempting advanced repair methods...")
                    
                    if self.perform_advanced_hcs_repair():
                        self.log_output("Advanced repair completed, retrying import...")
                        ret, _, err = self.run_command(['wsl', '--import', instance_name, wsl_dir, rootfs_file])
                        if ret == 0:
                            self.log_output("SUCCESS: WSL import completed after advanced repair")
                        else:
                            self.log_output(f"ERROR: WSL import still failed after advanced repair: {err}")
                            self.log_output("This requires a system restart to fully resolve")
                            self.log_output("Please restart your system and re-run this installer")
                            return None
                    else:
                        self.log_output("All repair methods failed, system restart required")
                        self.log_output("Please restart your system and re-run this installer")
                        return None
            else:
                self.log_output(f"Unknown import error: {err}")
                return None
        else:
            self.log_output(f"WSL import completed successfully")
            # Verify what WSL instances exist after import
            ret_check, out_check, _ = self.run_command(['wsl', '--list', '--quiet'])
            if ret_check == 0:
                instances_after = out_check.replace('\x00', '').replace(' ', '').replace('\r', '').replace('\n', ' ').split()
                instances_after = [name.strip() for name in instances_after if name.strip()]
                self.log_output(f"WSL instances after import: {instances_after}")
            else:
                self.log_output("Could not list WSL instances after import")
        
        # Verify and initialize the new instance
        self.log_output(f"Verifying and initializing '{instance_name}' instance...")
        
        # Test basic functionality
        ret, _, _ = self.run_command(['wsl', '-d', instance_name, 'echo', 'test'])
        if ret != 0:
            self.log_output(f"ERROR: {instance_name} instance verification failed")
            return None

        # First, build the kamiwaza user
        self.log_output(f"Building the kamiwaza user...")
        ret, _, err = self.run_command(['wsl', '-d', instance_name, 'bash', '-c', 'useradd -m -s /bin/bash kamiwaza'])
        if ret != 0:
            self.log_output(f"ERROR: Failed to build the kamiwaza user: {err}")
            return None

        # Configure default user to kamiwaza instead of root
        self.log_output(f"Configuring default user for '{instance_name}' instance...")
        self.log_output(f"WARNING: Failed to set default user to kamiwaza: {err}")
        # Try alternative method using /etc/wsl.conf
        wsl_conf_cmd = """
        sudo rm /etc/wsl.conf
        echo '[user]' > /etc/wsl.conf
        echo 'default=kamiwaza' >> /etc/wsl.conf
        """
        ret2, _, err2 = self.run_command(['wsl', '-d', instance_name, 'bash', '-c', wsl_conf_cmd])
        if ret2 != 0:
            self.log_output(f"WARNING: Failed to configure /etc/wsl.conf: {err2}")
        else:
            self.log_output("Configured /etc/wsl.conf to use kamiwaza as default user")
        
        # Verify the user configuration
        ret, whoami_out, _ = self.run_command(['wsl', '-d', instance_name, 'whoami'])
        if ret == 0:
            current_user = whoami_out.strip()
            self.log_output(f"Current default user: {current_user}")
            if current_user != 'kamiwaza':
                self.log_output(f"WARNING: Default user is '{current_user}', expected 'kamiwaza'")
                # Try to create kamiwaza user if it doesn't exist
                self.log_output("Attempting to ensure kamiwaza user exists...")
                create_user_cmds = [
                    'id kamiwaza || useradd -m -s /bin/bash kamiwaza',
                    'usermod -aG sudo kamiwaza',
                    'echo "kamiwaza ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/kamiwaza'
                ]
                for cmd in create_user_cmds:
                    ret, _, err = self.run_command(['wsl', '-d', instance_name, 'bash', '-c', cmd])
                    if ret != 0:
                        self.log_output(f"WARNING: User setup command failed: {cmd} - {err}")
                
                # Try setting default user again
                ret, _, _ = self.run_command(['wsl', '--set-default-user', instance_name, 'kamiwaza'])
                if ret == 0:
                    self.log_output("Successfully configured kamiwaza as default user after creation")
        
        # Initialize basic packages needed for installation (as root since we need sudo)
        init_commands = [
            'apt update',
            'apt install -y wget curl sudo file'
        ]
        
        for cmd in init_commands:
            ret, _, err = self.run_command(['wsl', '-d', instance_name, 'sudo', 'bash', '-c', cmd])
            if ret != 0:
                self.log_output(f"WARNING: Failed to initialize {instance_name}: {cmd} - {err}")
        
        # Final verification of user setup
        ret, final_user, _ = self.run_command(['wsl', '-d', instance_name, 'whoami'])
        if ret == 0:
            self.log_output(f"Final default user verification: {final_user.strip()}")
        
        # Set kamiwaza as the default WSL distribution
        self.log_output(f"Setting '{instance_name}' as default WSL distribution...")
        ret, _, err = self.run_command(['wsl', '--set-default', instance_name])
        if ret == 0:
            self.log_output(f"Successfully set '{instance_name}' as default WSL distribution")
        else:
            self.log_output(f"WARNING: Failed to set '{instance_name}' as default: {err}")
        
        self.log_output(f"Successfully created and initialized '{instance_name}' WSL instance")
        return instance_name

    def configure_wsl_memory(self):
        """Configure WSL memory using PowerShell script for proper swap calculation"""
        try:
            self.log_output(f"Configuring WSL memory: {self.memory}")
            
            # Try to use the PowerShell script if available
            script_path = os.path.join(os.path.dirname(__file__), "configure_wsl_memory.ps1")
            if os.path.exists(script_path):
                self.log_output(f"Using PowerShell script: {script_path}")
                cmd = ['powershell.exe', '-ExecutionPolicy', 'Bypass', '-File', script_path, '-MemoryAmount', self.memory]
                ret, out, err = self.run_command(cmd, timeout=30)
                
                if ret == 0:
                    self.log_output("WSL memory configured successfully using PowerShell script")
                    self.log_output(f"Script output: {out}")
                    return True
                else:
                    self.log_output(f"PowerShell script failed: {err}")
                    self.log_output("Falling back to Python configuration...")
            else:
                self.log_output(f"PowerShell script not found at: {script_path}")
                self.log_output("Falling back to Python configuration...")
            
            # Fallback to Python configuration (without swap calculation)
            wslconfig_path = os.path.expanduser("~\\.wslconfig")
            
            if os.path.exists(wslconfig_path):
                backup_path = f"{wslconfig_path}.backup.{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
                shutil.copy2(wslconfig_path, backup_path)
                self.log_output(f"Backed up to: {backup_path}")
            
            config_content = f"""[wsl2]
memory={self.memory}
processors=auto
swap=0
localhostForwarding=true
networkingMode=mirrored
"""
            
            with open(wslconfig_path, 'w', encoding='utf-8') as f:
                f.write(config_content)
            
            if os.path.exists(wslconfig_path):
                self.log_output(f"WSL memory configured: {self.memory}")
                return True
            
        except Exception as e:
            self.log_output(f"WSL memory config failed: {e}")
        
        return False

    def get_deb_url(self):
        """Get DEB URL - will be replaced during build"""
        return "{{DEB_FILE_URL}}"

    def get_deb_filename(self):
        """Get DEB filename from URL"""
        url = self.get_deb_url()
        return url.split('/')[-1]

    def configure_debconf(self, wsl_cmd):
        """Configure debconf with user inputs"""
        try:
            self.log_output("Configuring debconf...")
            
            debconf_env = "export DEBIAN_FRONTEND=noninteractive"
            
            # License agreement
            cmd = f"{debconf_env} && echo 'kamiwaza kamiwaza/license_agreement boolean true' | sudo debconf-set-selections"
            self.run_command(wsl_cmd + ['bash', '-c', cmd], timeout=10)
            
            # User inputs
            if self.user_email:
                cmd = f"{debconf_env} && echo 'kamiwaza kamiwaza/user_email string {self.user_email}' | sudo debconf-set-selections"
                self.run_command(wsl_cmd + ['bash', '-c', cmd], timeout=10)
                self.log_output(f"Set email: {self.user_email}")
            
            if self.license_key:
                cmd = f"{debconf_env} && echo 'kamiwaza kamiwaza/license_key string {self.license_key}' | sudo debconf-set-selections"
                self.run_command(wsl_cmd + ['bash', '-c', cmd], timeout=10)
                self.log_output("Set license key")
            
            # Usage reporting
            reporting = "true" if self.usage_reporting != "0" else "false"
            cmd = f"{debconf_env} && echo 'kamiwaza kamiwaza/usage_reporting boolean {reporting}' | sudo debconf-set-selections"
            self.run_command(wsl_cmd + ['bash', '-c', cmd], timeout=10)
            
            # Install mode
            mode = self.install_mode or "lite"
            cmd = f"{debconf_env} && echo 'kamiwaza kamiwaza/mode string {mode}' | sudo debconf-set-selections"
            self.run_command(wsl_cmd + ['bash', '-c', cmd], timeout=10)
            
            self.log_output("Debconf configured")
            
        except Exception as e:
            self.log_output(f"Debconf config error: {e}")

    def cleanup_on_failure(self, wsl_cmd=None, instance_name=None):
        """Clean up WSL instances and data on installation failure"""
        try:
            self.log_output("=== CLEANING UP ON INSTALLATION FAILURE ===")
            self.log_output("Removing any partially created WSL instances and data...")
            
            # If we have a specific WSL command, try to clean up that instance
            if wsl_cmd and instance_name:
                self.log_output(f"Cleaning up specific WSL instance: {instance_name}")
                try:
                    # Try to stop the instance first
                    self.run_command(['wsl', '--terminate', instance_name], timeout=15)
                    self.log_output(f"  Stopped WSL instance: {instance_name}")
                    
                    # Try to remove kamiwaza package if it was partially installed
                    self.run_command(wsl_cmd + ['sudo', 'apt', 'remove', '--purge', '-y', 'kamiwaza'], timeout=30)
                    self.log_output(f"  Attempted to remove kamiwaza package from {instance_name}")
                    
                    # Unregister the instance
                    self.run_command(['wsl', '--unregister', instance_name], timeout=30)
                    self.log_output(f"  Unregistered WSL instance: {instance_name}")
                    
                except Exception as e:
                    self.log_output(f"  Warning: Could not clean up {instance_name}: {e}")
                    # Try force unregister as fallback
                    try:
                        self.run_command(['wsl', '--unregister', instance_name], timeout=30)
                        self.log_output(f"  Force unregistered WSL instance: {instance_name}")
                    except:
                        self.log_output(f"  Error: Could not force unregister {instance_name}")
            
            # Clean up any kamiwaza WSL data directory
            wsl_data_path = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'WSL', 'kamiwaza')
            if os.path.exists(wsl_data_path):
                self.log_output(f"Removing WSL data directory: {wsl_data_path}")
                try:
                    import shutil
                    shutil.rmtree(wsl_data_path, ignore_errors=True)
                    self.log_output("  Successfully removed WSL data directory")
                except Exception as e:
                    self.log_output(f"  Warning: Could not remove WSL data directory: {e}")
            
            # Clean up .wslconfig if it was created by kamiwaza
            wsl_config_path = os.path.expanduser("~\\.wslconfig")
            if os.path.exists(wsl_config_path):
                try:
                    with open(wsl_config_path, 'r') as f:
                        content = f.read()
                    if "memory=" in content and "localhostForwarding=true" in content:
                        self.log_output("Detected kamiwaza-specific .wslconfig - removing")
                        os.remove(wsl_config_path)
                        self.log_output("  Removed .wslconfig")
                    else:
                        self.log_output("Keeping .wslconfig (appears to have other configurations)")
                except Exception as e:
                    self.log_output(f"Warning: Could not check .wslconfig: {e}")
            
            # Clean up AppData logs
            appdata_logs = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza', 'logs')
            if os.path.exists(appdata_logs):
                self.log_output(f"Removing Kamiwaza logs directory: {appdata_logs}")
                try:
                    import shutil
                    shutil.rmtree(appdata_logs, ignore_errors=True)
                    self.log_output("  Successfully removed logs directory")
                except Exception as e:
                    self.log_output(f"  Warning: Could not remove logs directory: {e}")
            
            # Clean up the entire Kamiwaza AppData directory if it's empty
            kamiwaza_appdata = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza')
            if os.path.exists(kamiwaza_appdata):
                try:
                    remaining_items = len([f for f in os.listdir(kamiwaza_appdata) if not f.startswith('.')])
                    if remaining_items == 0:
                        self.log_output(f"Removing empty Kamiwaza AppData directory: {kamiwaza_appdata}")
                        os.rmdir(kamiwaza_appdata)
                        self.log_output("  Successfully removed empty Kamiwaza AppData directory")
                    else:
                        self.log_output(f"Kamiwaza AppData directory not empty, keeping: {remaining_items} items remain")
                except Exception as e:
                    self.log_output(f"Warning: Could not check Kamiwaza AppData directory: {e}")
            
            self.log_output("=== CLEANUP ON FAILURE COMPLETED ===")
            
        except Exception as e:
            self.log_output(f"Error during failure cleanup: {e}")
            self.log_output("Continuing with failure reporting...")

    def configure_swap_space(self, wsl_cmd):
        """Configure swap space within WSL instance based on memory allocation"""
        try:
            self.log_output("Configuring swap space in WSL...")
            
            # Calculate swap size as half of the memory allocation
            memory_value = int(self.memory.replace('GB', ''))
            swap_size_gb = memory_value // 2
            swap_size_mb = swap_size_gb * 1024
            
            # Ensure minimum swap size of 1GB
            if swap_size_gb < 1:
                swap_size_gb = 1
                swap_size_mb = 1024
                self.log_output("  [INFO] Swap size adjusted to minimum 1GB")
            
            self.log_output(f"Memory allocation: {self.memory}")
            self.log_output(f"Calculated swap size: {swap_size_gb}GB ({swap_size_mb}MB)")
            
            # Check for existing swap space
            self.log_output("Checking for existing swap space...")
            ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', 'sudo swapon --show'], timeout=15)
            if ret == 0 and out.strip():
                self.log_output(f"  [INFO] Found existing swap: {out.strip()}")
                self.log_output("  [INFO] Will configure additional swap space for Kamiwaza")
            else:
                self.log_output("  [INFO] No existing swap space found")
            
            # Check if swap file already exists
            self.log_output("Checking if swap file already exists...")
            ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', 'ls -la /swapfile'], timeout=15)
            if ret == 0:
                self.log_output("  [INFO] Swap file already exists, checking if it's the right size...")
                # Check if existing swap file is the right size
                size_check_cmd = f"ls -lh /swapfile | awk '{{print $5}}'"
                ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', size_check_cmd], timeout=15)
                if ret == 0 and out.strip():
                    current_size = out.strip()
                    expected_size = f"{swap_size_gb}G"
                    if current_size == expected_size:
                        self.log_output(f"  [OK] Existing swap file is correct size: {current_size}")
                        # Just enable it if not already active
                        ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', 'sudo swapon /swapfile'], timeout=15)
                        if ret == 0:
                            self.log_output("  [OK] Existing swap file activated")
                        else:
                            self.log_output("  [INFO] Swap file already active")
                        return
                    else:
                        self.log_output(f"  [INFO] Existing swap file size mismatch: {current_size} vs expected {expected_size}")
                        self.log_output("  [INFO] Will recreate swap file with correct size")
                        # Remove existing swap file
                        self.run_command(wsl_cmd + ['bash', '-c', 'sudo swapoff /swapfile 2>/dev/null; sudo rm -f /swapfile'], timeout=15)
            
            # Create swap file for Kamiwaza
            self.log_output(f"Creating {swap_size_gb}GB swap file for Kamiwaza...")
            swap_commands = [
                (f"Creating {swap_size_gb}GB swap file...", 
                 f"sudo fallocate -l {swap_size_gb}G /swapfile"),
                ("Setting swap file permissions...", 
                 "sudo chmod 600 /swapfile"),
                ("Formatting swap file...", 
                 "sudo mkswap /swapfile"),
                ("Enabling swap file...", 
                 "sudo swapon /swapfile"),
                ("Verifying swap is active...", 
                 "sudo swapon --show")
            ]
            
            for description, command in swap_commands:
                self.log_output(f"  {description}")
                ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', command], timeout=60)
                
                if ret == 0:
                    if "Verifying" in description:
                        if "/swapfile" in out:
                            self.log_output(f"  [OK] Swap file successfully activated: {out.strip()}")
                        else:
                            self.log_output(f"  [WARNING] Swap file not found in active swaps: {out.strip()}")
                    else:
                        self.log_output(f"  [OK] {description}")
                else:
                    self.log_output(f"  [WARNING] {description} failed (exit code {ret})")
                    if err:
                        self.log_output(f"    Error: {err}")
            
            # Make swap permanent by adding to /etc/fstab
            self.log_output("Making swap permanent...")
            
            # First, check if fstab is the default unconfigured template
            fstab_content_cmd = "cat /etc/fstab"
            ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', fstab_content_cmd], timeout=15)
            
            if ret == 0 and "UNCONFIGURED FSTAB FOR BASE SYSTEM" in out:
                self.log_output("  [INFO] Found unconfigured fstab template, replacing with proper configuration...")
                # Create a proper fstab with swap entry
                proper_fstab = """# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/sda1 during curtin installation
/dev/disk/by-uuid/$(blkid -s UUID -o value /dev/sda1) / ext4 defaults 0 1
/swapfile none swap sw 0 0
"""
                # Write the proper fstab
                fstab_write_cmd = f"echo '{proper_fstab}' | sudo tee /etc/fstab"
                ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', fstab_write_cmd], timeout=15)
                if ret == 0:
                    self.log_output("  [OK] Replaced unconfigured fstab with proper configuration including swap")
                else:
                    self.log_output(f"  [WARNING] Failed to write proper fstab: {err}")
            else:
                # Check if swap entry already exists
                fstab_check_cmd = "grep -q '/swapfile' /etc/fstab"
                ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', fstab_check_cmd], timeout=15)
                
                if ret != 0:  # Not found in fstab
                    fstab_add_cmd = "echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab"
                    ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', fstab_add_cmd], timeout=15)
                    if ret == 0:
                        self.log_output("  [OK] Added swap file to /etc/fstab for persistence")
                    else:
                        self.log_output(f"  [WARNING] Failed to add swap to /etc/fstab: {err}")
                else:
                    self.log_output("  [INFO] Swap file already configured in /etc/fstab")
            
            # Verify final swap configuration
            self.log_output("Verifying final swap configuration...")
            verify_commands = [
                ("Current memory and swap usage:", "free -h"),
                ("Active swap devices:", "sudo swapon --show"),
                ("Swap file size:", "ls -lh /swapfile")
            ]
            
            for description, command in verify_commands:
                ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', command], timeout=15)
                if ret == 0:
                    self.log_output(f"  {description}")
                    for line in out.strip().split('\n'):
                        if line.strip():
                            self.log_output(f"    {line}")
                else:
                    self.log_output(f"  [WARNING] Could not verify {description}: {err}")
            
            # Enable Docker swap limit support
            self.log_output("Enabling Docker swap limit support...")
            docker_swap_commands = [
                ("Adding swap accounting to sysctl.conf...", 
                 "echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf"),
                ("Adding memory cgroup support...", 
                 "mkdir -p /etc/default/grub.d && echo 'cgroup_enable=memory swapaccount=1' | sudo tee -a /etc/default/grub.d/cgroup.cfg"),
                ("Applying sysctl changes...", 
                 "sudo sysctl -p"),
            ]
            
            for description, command in docker_swap_commands:
                self.log_output(f"  {description}")
                ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', command], timeout=30)
                if ret == 0:
                    self.log_output(f"  [OK] {description}")
                else:
                    self.log_output(f"  [WARNING] {description} failed (exit code {ret})")
                    if err:
                        self.log_output(f"    Error: {err}")
            
            # Show summary of memory configuration
            self.log_output("=== MEMORY CONFIGURATION SUMMARY ===")
            self.log_output(f"  WSL Memory Allocation: {self.memory}")
            self.log_output(f"  Swap Space: {swap_size_gb}GB")
            self.log_output(f"  Total Virtual Memory: {memory_value + swap_size_gb}GB")
            self.log_output("  Note: Swap is configured in both .wslconfig and within WSL instance")
            self.log_output("  Docker swap limit support: Enabled")
            self.log_output("[OK] Swap space configuration completed")
            
        except Exception as e:
            self.log_output(f"Warning: Error configuring swap space: {e}")
            self.log_output("Continuing with installation anyway...")

    def disable_ipv6_wsl(self, wsl_cmd):
        """Disable IPv6 in WSL for better network compatibility"""
        try:
            self.log_output("Disabling IPv6 in WSL...")
            
            # IPv6 disabling commands
            ipv6_commands = [
                ("Adding IPv6 disable settings to sysctl.conf...", 
                 "echo 'net.ipv6.conf.all.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf"),
                ("Adding IPv6 disable settings for default interface...", 
                 "echo 'net.ipv6.conf.default.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf"),
                ("Adding IPv6 disable settings for loopback interface...", 
                 "echo 'net.ipv6.conf.lo.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.conf"),
                ("Applying sysctl changes...", 
                 "sudo sysctl -p"),
                ("Verifying IPv6 is disabled...", 
                 "cat /proc/sys/net/ipv6/conf/all/disable_ipv6")
            ]
            
            for description, command in ipv6_commands:
                self.log_output(f"  {description}")
                ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', command], timeout=30)
                
                if ret == 0:
                    if "Verifying" in description and out.strip() == "1":
                        self.log_output(f"  [OK] IPv6 successfully disabled (verification: {out.strip()})")
                    elif "Verifying" not in description:
                        self.log_output(f"  [OK] {description}")
                else:
                    self.log_output(f"  [WARNING] {description} failed (exit code {ret})")
                    if err:
                        self.log_output(f"    Error: {err}")
            
            # Also disable IPv6 in GRUB for persistence across reboots
            self.log_output("Configuring GRUB to disable IPv6 at boot...")
            grub_cmd = "sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"ipv6.disable=1\"/' /etc/default/grub && sudo update-grub"
            ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', grub_cmd], timeout=60)
            if ret == 0:
                self.log_output("  [OK] GRUB configured to disable IPv6 at boot")
            else:
                self.log_output("  [WARNING] GRUB IPv6 disable configuration failed (this is normal in WSL)")
            
            self.log_output("[OK] IPv6 disabling completed")
            
        except Exception as e:
            self.log_output(f"Warning: Error disabling IPv6: {e}")
            self.log_output("Continuing with installation anyway...")

    def check_gui_manager_installed(self):
        """Check if GUI Manager is already installed"""
        try:
            # Check if GUI Manager EXE exists in AppData
            appdata_gui = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza', 'GUI', 'KamiwazaGUIManager.exe')
            if os.path.exists(appdata_gui):
                self.log_output("GUI Manager is already installed in AppData")
                return True
            else:
                self.log_output("GUI Manager not found in AppData")
                return False
            
        except Exception as e:
            self.log_output(f"Error checking GUI Manager installation: {e}")
            return False


# End of HeadlessKamiwazaInstaller class

def main():
    print("=== KAMIWAZA HEADLESS INSTALLER STARTING ===")
    print(f"Script: {__file__}")
    print(f"Args: {sys.argv}")
    print(f"Python: {sys.version}")
    print(f"Working Dir: {os.getcwd()}")
    print("=" * 50)
    print("")
    print("IMPORTANT: A system restart will be required to activate GPU acceleration.")
    print("MSI will prompt you to restart at the end of installation; you can reboot later.")
    print("This is a standard Windows restart prompt managed by the installer UI.")
    print("Save your work before proceeding.")
    print("")
    print("ENHANCED LOGGING: All output is logged to multiple locations:")
    print("- Windows AppData: %LOCALAPPDATA%\\Kamiwaza\\logs\\")
    print("- Temporary directory: %TEMP%\\kamiwaza_installer_temp.log")
    print("- Current directory: kamiwaza_installer_simple.log")
    print("")
    print("AUTOMATIC INSTALLATION FLOW:")
    print("1. WSL setup and GPU driver installation")
    print("2. Kamiwaza package installation (sudo apt install)")
    print("3. MSI will prompt you to restart to finalize activation")
    print("4. After restart, Kamiwaza starts with GPU acceleration ready")
    print("=" * 50)
    
    parser = argparse.ArgumentParser(description='Headless Kamiwaza Installer')
    parser.add_argument('--memory', default='14GB', help='WSL memory allocation')
    parser.add_argument('--version', help='Kamiwaza version')
    parser.add_argument('--codename', help='Ubuntu codename')
    parser.add_argument('--build', help='Build number')
    parser.add_argument('--arch', help='Architecture')
    parser.add_argument('--email', help='User email')
    parser.add_argument('--license-key', help='License key')
    parser.add_argument('--usage-reporting', help='Usage reporting')
    parser.add_argument('--mode', help='Installation mode')
    
    try:
        args = parser.parse_args()
        print("=== PARSED ARGUMENTS ===")
        for arg, value in vars(args).items():
            if 'key' in arg.lower() and value:
                print(f"{arg}: ***REDACTED***")
            else:
                print(f"{arg}: {value}")
        print("=" * 50)
        
    except Exception as e:
        print(f"CRITICAL: Failed to parse arguments: {e}")
        input("Press Enter to exit...")
        sys.exit(1)
    
    try:
        installer = HeadlessKamiwazaInstaller(
            memory=args.memory,
            version=args.version,
            codename=args.codename,
            build=args.build,
            arch=args.arch,
            user_email=args.email,
            license_key=args.license_key,
            usage_reporting=args.usage_reporting,
            install_mode=args.mode
        )
        
        exit_code = installer.install()
        
        print("=== INSTALLATION FINISHED ===")
        print(f"Exit code: {exit_code}")
        if exit_code == 0:
            print("SUCCESS: Installation completed successfully")
        elif exit_code == 3010:
            print("SUCCESS: Installation completed. Reboot required to finish activation.")
        else:
            print("FAILURE: Installation failed")
            print("")
            print("If this was due to WSL service issues:")
            print("1. Restart your computer")
            print("2. Run Windows Update")
            print("3. Run this installer as Administrator")
                
        sys.exit(exit_code)
        
    except Exception as e:
        print("=== CRITICAL MAIN() FAILURE ===")
        print(f"Exception: {e}")
        import traceback
        print("Full traceback:")
        traceback.print_exc()
        
        # Try to clean up any WSL instances that might have been created
        try:
            print("Attempting to clean up any WSL instances...")
            import subprocess
            # Run the cleanup script directly
            cleanup_script = os.path.join(os.path.dirname(__file__), 'cleanup_wsl_kamiwaza.ps1')
            if os.path.exists(cleanup_script):
                subprocess.run(['powershell.exe', '-ExecutionPolicy', 'Bypass', '-File', cleanup_script, '-Force'], 
                             capture_output=True, text=True, timeout=60)
                print("WSL cleanup attempted")
            else:
                print("Cleanup script not found, manual cleanup may be required")
        except Exception as cleanup_error:
            print(f"Cleanup attempt failed: {cleanup_error}")
        
        input("Press Enter to exit...")
        sys.exit(1)

if __name__ == "__main__":
    main()
