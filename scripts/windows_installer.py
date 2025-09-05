import tkinter as tk
from tkinter import ttk, messagebox
from threading import Thread
import subprocess
import sys
import os
import ftfy
import tempfile
import shutil
import argparse
import yaml
import platform
import datetime

# --- LOG FILE LOCATION ---
def get_log_file_path():
    local_appdata = os.environ.get("LOCALAPPDATA")
    log_dir = os.path.join(local_appdata, "Kamiwaza")
    os.makedirs(log_dir, exist_ok=True)
    return os.path.join(log_dir, "kamiwaza_installer.log")

def log_with_timestamp(message):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_line = f"[{timestamp}] {message}"
    log_path = get_log_file_path()
    try:
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(log_line + "\n")
    except Exception:
        pass
    print(log_line)

# --- ADMIN CHECK (only for WSL memory config) ---
def is_windows_admin():
    try:
        import ctypes
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False

def check_windows_admin():
    if not is_windows_admin():
        tk.Tk().withdraw()
        messagebox.showerror("Administrator Privileges Required", "This installer must be run as Administrator.")
        sys.exit(1)

# Check for passwordless sudo in WSL
def has_passwordless_sudo_wsl():
    try:
        ret = subprocess.call(["wsl", "sudo", "-n", "true"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return ret == 0
    except Exception:
        return False

def check_wsl_passwordless_sudo():
    if not has_passwordless_sudo_wsl():
        tk.Tk().withdraw()
        messagebox.showerror(
            "Passwordless sudo required in WSL",
            "Passwordless sudo is required in your WSL instance for unattended installation. Please configure it and try again."
        )
        sys.exit(1)

# --- ROBUST LOGGING SETUP ---
# This block is now redundant as log_with_timestamp is moved to the top
# def get_log_file_path():
#     # Use environment variable or default
#     return os.environ.get("KAMIWAZA_INSTALLER_LOG", os.path.abspath("kamiwaza_installer.log"))

# def log_with_timestamp(message):
#     timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
#     log_line = f"[{timestamp}] {message}"
#     log_path = get_log_file_path()
#     try:
#         with open(log_path, "a", encoding="utf-8") as f:
#             f.write(log_line + "\n")
#     except Exception:
#         pass
#     print(log_line)

# --- ENFORCE PRIVILEGE CHECKS EARLY ---
# This block is now redundant as check_windows_admin is moved to configure_wsl_memory
# check_windows_admin()

try:
    import yaml
except ImportError:
    import sys
    import tkinter as tk
    from tkinter import messagebox
    root = tk.Tk()
    root.withdraw()
    messagebox.showerror("Missing Dependency", "PyYAML is not installed. Please run 'pip install -r requirements.txt' in your venv.")
    sys.exit(1)

def ensure_wsl_prereqs():
    prereqs = [
        "bash", "wget", "curl", "sudo", "apt-utils",
        "ca-certificates", "dpkg", "coreutils", "lsb-release"
    ]
    print("[INFO] Ensuring WSL prerequisites are installed...")
    try:
        subprocess.check_call(["wsl", "sudo", "apt-get", "update"])
        subprocess.check_call(["wsl", "sudo", "apt-get", "install", "-y"] + prereqs)
        print("[SUCCESS] All prerequisites installed.")
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Failed to install prerequisites in WSL: {e}")
        exit(1)

class KamiwazaInstaller(tk.Tk):
    def __init__(self, debug=False, memory="14GB", config_path="config.yaml", version=None, codename=None, build=None, arch=None, test_mode=False, user_email=None, license_key=None, usage_reporting=None, install_mode=None):
        super().__init__()
        self.title("Kamiwaza Installer")
        self.geometry("600x400")
        
        # Keep window on top and in focus
        self.attributes('-topmost', True)
        self.focus_force()
        self.lift()
        
        # Center the window on screen
        self.center_window()
        
        self.debug = debug
        self.memory = memory
        self.test_mode = test_mode
        self.user_email = user_email
        self.license_key = license_key
        self.usage_reporting = usage_reporting
        self.install_mode = install_mode
        self.log_file_path = get_log_file_path()
        # Always-on logging
        try:
            self.log_file = open(self.log_file_path, "a", encoding="utf-8")
        except (PermissionError, OSError) as e:
            print(f"Warning: Could not create log file: {e}")
            self.log_file = None

        # Change working directory to installer directory if we're in system32
        if os.getcwd().lower().endswith('system32'):
            # Try to find the installer directory
            installer_dir = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza')
            if os.path.exists(installer_dir):
                os.chdir(installer_dir)
        
        # Load config - but we can't log yet since log_output needs the window
        self.config = {}
        self.config_path = config_path
        self.kamiwaza_version = version or '0.5.0-rc1'
        self.codename = codename or 'noble' 
        self.build_number = build or 1
        self.arch = arch or 'auto'

        # Progress bar
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(self, variable=self.progress_var, maximum=100)
        self.progress_bar.pack(fill='x', padx=20, pady=10)

        # Status label
        self.status_label = ttk.Label(self, text="Starting Kamiwaza installation...", font=('Arial', 10, 'bold'))
        self.status_label.pack(pady=5)

        # Log output
        self.log_text = tk.Text(self, wrap='word', height=12, font=('Courier', 10))
        self.log_text.pack(fill='both', expand=True, padx=20, pady=10)

        # Install button (hidden since we auto-start)
        self.install_button = ttk.Button(self, text="Install in WSL", command=self.start_installation)
        self.install_button.pack(pady=10)
        self.install_button.pack_forget()  # Hide the button

        # Close button (hidden by default)
        self.close_button = ttk.Button(self, text="Close", command=self.quit)
        self.close_button.pack(pady=10)
        self.close_button.pack_forget()

        # Launch Ubuntu Shell button (hidden by default)
        self.launch_shell_button = ttk.Button(self, text="Launch Ubuntu Shell", command=self.launch_ubuntu_shell)
        self.launch_shell_button.pack(pady=10)
        self.launch_shell_button.pack_forget()

        # Auto-start installation after a short delay to let UI initialize
        if not has_passwordless_sudo_wsl():
            self.try_configure_passwordless_sudo_wsl(on_success=self.start_installation)
            return
        self.after(500, self.start_installation)
        
        # Periodically bring window to front during installation
        self.schedule_window_focus()

        # Show log button
        if self.debug:
            self.show_log_button = ttk.Button(self, text="Show Log File", command=self.show_log_file)
            self.show_log_button.pack(pady=5)

        # Now load config properly with logging available
        self.log_output("DEBUG: Initializing config loading...")
        self.config = self.load_config(self.config_path)
        
        # Override with config values if not provided via args
        if not version:
            self.kamiwaza_version = self.config.get('kamiwaza_version', '0.5.0-rc1')
        if not codename:
            self.codename = self.config.get('codename', 'noble')
        if not build:
            self.build_number = self.config.get('build_number', 1)
        if not arch:
            self.arch = self.config.get('arch', 'auto')
        
        if self.arch == 'auto':
            self.arch = self.detect_arch()
        
        self.log_output(f"DEBUG: Final config values after loading:")
        self.log_output(f"DEBUG: - kamiwaza_version: {self.kamiwaza_version}")
        self.log_output(f"DEBUG: - codename: {self.codename}")
        self.log_output(f"DEBUG: - build_number: {self.build_number}")
        self.log_output(f"DEBUG: - arch: {self.arch}")
        self.log_output(f"DEBUG: User inputs from MSI:")
        self.log_output(f"DEBUG: - user_email: {self.user_email}")
        self.log_output(f"DEBUG: - license_key: {'[SET]' if self.license_key else '[NOT SET]'}")
        self.log_output(f"DEBUG: - usage_reporting: {self.usage_reporting}")
        self.log_output(f"DEBUG: - install_mode: {self.install_mode}")

        # Enforce WSL sudo check at start, but try to auto-configure if missing
        if not has_passwordless_sudo_wsl():
            self.try_configure_passwordless_sudo_wsl(on_success=self.start_installation)
            return

    def log_output(self, message):
        import datetime
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_line = f"[{timestamp}] {message}"
        
        # Ensure window exists before updating UI
        try:
            self.log_text.insert(tk.END, log_line + "\n")
            self.log_text.see(tk.END)
            self.update()
            # Bring window to front for important messages
            if any(keyword in message.lower() for keyword in ['error', 'success', 'complete', 'installing', 'downloading']):
                self.bring_to_front()
        except tk.TclError:
            pass  # Window might be destroyed
        
        try:
            if self.log_file is not None:
                self.log_file.write(log_line + "\n")
                self.log_file.flush()
        except (OSError, IOError):
            self.log_file = None
        log_with_timestamp(message)

    def center_window(self):
        """Center the window on the screen"""
        self.update_idletasks()
        width = 600
        height = 400
        x = (self.winfo_screenwidth() // 2) - (width // 2)
        y = (self.winfo_screenheight() // 2) - (height // 2)
        self.geometry(f'{width}x{height}+{x}+{y}')
    
    def bring_to_front(self):
        """Bring the window to the front and focus it"""
        try:
            self.lift()
            self.focus_force()
            self.attributes('-topmost', True)
            self.after_idle(lambda: self.attributes('-topmost', False))
        except Exception:
            pass  # Ignore errors if window is being destroyed
    
    def schedule_window_focus(self):
        """Schedule window focusing only a couple of times during installation"""
        # Only bring to front at start and after major steps
        if not hasattr(self, 'focus_count'):
            self.focus_count = 0
        if self.focus_count < 2:
            self.bring_to_front()
            self.focus_count += 1
            # Schedule next focus attempt in 10 seconds (only twice)
            self.focus_job = self.after(10000, self.schedule_window_focus)
        # After two times, do not schedule again

    def is_windows_server(self):
        """Detect if running on Windows Server"""
        try:
            import platform
            # Check platform string
            platform_str = platform.platform().lower()
            if 'server' in platform_str:
                return True
            
            # Check using systeminfo command - look specifically for "Windows Server" in OS Name line
            ret, out, err = self.run_command(['systeminfo'], timeout=30)
            if ret == 0 and out:
                for line in out.split('\n'):
                    if 'OS Name:' in line and 'windows server' in line.lower():
                        return True
            
            # Check using ver command
            ret, out, err = self.run_command(['ver'], timeout=10)
            if ret == 0 and out:
                if 'server' in out.lower():
                    return True
            
            # Check registry for Windows Server - look for exact "Windows Server" in ProductName
            try:
                import winreg
                key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, 
                    r"SOFTWARE\Microsoft\Windows NT\CurrentVersion")
                value, _ = winreg.QueryValueEx(key, "ProductName")
                winreg.CloseKey(key)
                if 'windows server' in value.lower():
                    return True
            except:
                pass
                
            return False
        except Exception as e:
            self.log_output(f"Error detecting Windows Server: {e}")
            return False
    
    def install_ubuntu_server(self):
        """Install Ubuntu on Windows Server using PowerShell method"""
        try:
            self.log_output("Installing Ubuntu on Windows Server...")
            
            # Enable WSL feature using DISM
            self.log_output("Enabling Windows Subsystem for Linux feature...")
            dism_cmd = ['dism.exe', '/online', '/enable-feature', '/featurename:Microsoft-Windows-Subsystem-Linux', '/all', '/norestart']
            ret, out, err = self.run_command(dism_cmd, timeout=120)
            if ret != 0:
                self.log_output(f"DISM command failed: {err}")
                return False
            
            # Download Ubuntu appx package
            ubuntu_url = "https://aka.ms/wslubuntu2004"
            appx_file = "Ubuntu.appx"
            
            self.log_output(f"Downloading Ubuntu from {ubuntu_url}...")
            download_cmd = f"""
                Invoke-WebRequest -Uri '{ubuntu_url}' -OutFile '{appx_file}' -UseBasicParsing
            """
            ret, out, err = self.run_command(['powershell', '-Command', download_cmd], timeout=300)
            if ret != 0:
                self.log_output(f"Failed to download Ubuntu: {err}")
                return False
            
            # Extract the appx (it's actually a zip file)
            extract_dir = "Ubuntu_extracted"
            extract_cmd = f"""
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory('{appx_file}', '{extract_dir}')
            """
            ret, out, err = self.run_command(['powershell', '-Command', extract_cmd], timeout=60)
            if ret != 0:
                self.log_output(f"Failed to extract Ubuntu appx: {err}")
                return False
            
            # Find and extract the nested Ubuntu tar.gz
            find_cmd = f"""
                Get-ChildItem -Path '{extract_dir}' -Filter '*.tar.gz' | Select-Object -First 1 | ForEach-Object {{
                    $tarFile = $_.FullName
                    Write-Output "Found tar file: $tarFile"
                    # Extract using tar command
                    tar -xzf $tarFile -C ubuntu_install
                }}
            """
            ret, out, err = self.run_command(['powershell', '-Command', find_cmd], timeout=120)
            if ret != 0:
                self.log_output(f"Failed to extract Ubuntu rootfs: {err}")
                return False
            
            # Install Ubuntu by running ubuntu.exe
            ubuntu_exe_cmd = f"""
                if (Test-Path 'ubuntu_install\\ubuntu.exe') {{
                    Start-Process -FilePath 'ubuntu_install\\ubuntu.exe' -ArgumentList 'install', '--root' -Wait
                    Write-Output "Ubuntu installation completed"
                }} else {{
                    Write-Error "ubuntu.exe not found"
                }}
            """
            ret, out, err = self.run_command(['powershell', '-Command', ubuntu_exe_cmd], timeout=300)
            if ret != 0:
                self.log_output(f"Failed to install Ubuntu: {err}")
                return False
            
            self.log_output("Ubuntu installed successfully on Windows Server!")
            return True
            
        except Exception as e:
            self.log_output(f"Error installing Ubuntu on Windows Server: {e}")
            return False
    
    def update_progress(self, value):
        self.progress_var.set(value)
        self.update()
        # Bring window to front when progress updates
        self.bring_to_front()

    def run_command(self, command, real_time=False, timeout=None, show_in_wsl=False):
        self.log_output(f"Running: {' '.join(command)}")
        try:
            # Ensure UTF-8 output from subprocess
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "UTF-8"
            
            if show_in_wsl:
                # For commands that should be shown in WSL terminal (like installation scripts)
                import tempfile
                import time
                bat_file = tempfile.NamedTemporaryFile(delete=False, suffix='.bat', mode='w', encoding='utf-8')
                bat_file_path = bat_file.name
                # Compose the command string
                cmd_str = ' '.join(f'"{c}"' if ' ' in c else c for c in command)
                bat_file.write(f"{cmd_str}\n")
                bat_file.write('echo.\n')
                bat_file.write('echo [INFO] Command completed. Press any key to close this window...\n')
                bat_file.write('pause\n')
                bat_file.close()
                
                self.log_output(f"DEBUG: Opening terminal with batch file: {bat_file_path}")
                full_cmd = ['cmd', '/c', 'start', '"Kamiwaza WSL Install"', '/wait', 'cmd', '/k', bat_file_path]
                process = subprocess.Popen(full_cmd, shell=True)
                # Give it a moment to start
                time.sleep(1)
                # Clean up the temp file after a delay
                def cleanup_temp_file():
                    time.sleep(60)
                    try:
                        os.unlink(bat_file_path)
                    except:
                        pass
                from threading import Thread
                Thread(target=cleanup_temp_file).start()
                return 0, "", ""
            elif real_time:
                # For real-time output (like apt install) - hide console windows
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startupinfo.wShowWindow = subprocess.SW_HIDE
                
                process = subprocess.Popen(
                    command, 
                    stdout=subprocess.PIPE, 
                    stderr=subprocess.STDOUT, 
                    text=True, 
                    encoding='utf-8', 
                    env=env, 
                    bufsize=1, 
                    universal_newlines=True,
                    startupinfo=startupinfo,
                    creationflags=subprocess.CREATE_NO_WINDOW
                )
                stdout_lines = []
                if process.stdout:
                    while True:
                        output = process.stdout.readline()
                        if output == '' and process.poll() is not None:
                            break
                        if output:
                            output = output.strip()
                            stdout_lines.append(output)
                            self.log_output(output)  # Show immediately in UI
                            
                    # Get any remaining output
                    remaining_output = process.stdout.read()
                    if remaining_output:
                        for line in remaining_output.strip().split('\n'):
                            if line.strip():
                                stdout_lines.append(line)
                                self.log_output(line)
                
                return process.returncode, '\n'.join(stdout_lines), ""
            else:
                # Original method for quick commands - hide console windows
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
                try:
                    stdout, stderr = process.communicate(timeout=timeout)
                    if stdout:
                        self.log_output(stdout)
                    if stderr:
                        self.log_output(stderr)
                    return process.returncode, stdout, stderr
                except subprocess.TimeoutExpired:
                    process.kill()
                    self.log_output(f"Command timed out after {timeout} seconds")
                    return 1, "", f"Command timed out after {timeout} seconds"
                
        except Exception as e:
            self.log_output(f"Error running command: {e}")
            return 1, "", str(e)

    def configure_wsl_memory(self):
        """Configure WSL memory allocation using PowerShell script for proper swap calculation"""
        try:
            self.log_output(f"Configuring WSL memory allocation to {self.memory}...")
            
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
            self.log_output(f"DEBUG: Writing .wslconfig to: {wslconfig_path}")
            
            # Back up existing .wslconfig if it exists
            if os.path.exists(wslconfig_path):
                backup_path = f"{wslconfig_path}.backup.{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
                shutil.copy2(wslconfig_path, backup_path)
                self.log_output(f"Backed up existing .wslconfig to: {backup_path}")
            
            config_content = f"""[wsl2]
memory={self.memory}
processors=auto
swap=0
localhostForwarding=true
networkingMode=mirrored
"""
            
            with open(wslconfig_path, 'w', encoding='utf-8') as f:
                f.write(config_content)
            
            # Verify the file was written correctly
            if os.path.exists(wslconfig_path):
                with open(wslconfig_path, 'r', encoding='utf-8') as f:
                    written_content = f.read()
                if self.memory in written_content:
                    self.log_output(f"Successfully configured .wslconfig at {wslconfig_path}")
                    self.log_output(f"Memory allocation set to: {self.memory}")
                    self.log_output("WSL will use new memory settings after restart")
                    return True
                else:
                    self.log_output(f"ERROR: Memory setting not found in written .wslconfig file")
                    return False
            else:
                self.log_output(f"ERROR: .wslconfig file was not created at {wslconfig_path}")
                return False
        except Exception as e:
            self.log_output(f"Error configuring .wslconfig: {e}")
            self.log_output("This is not critical - WSL will use default settings.")
            return False

    def load_config(self, config_path):
        try:
            self.log_output(f"DEBUG: Attempting to load config from: {config_path}")
            self.log_output(f"DEBUG: Current working directory: {os.getcwd()}")
            self.log_output(f"DEBUG: Config file exists: {os.path.exists(config_path)}")
            
            if os.path.exists(config_path):
                with open(config_path, 'r') as f:
                    config_data = yaml.safe_load(f)
                    self.log_output(f"DEBUG: Successfully loaded config: {config_data}")
                    return config_data
            else:
                self.log_output(f"DEBUG: Config file not found at {config_path}")
                return {}
        except Exception as e:
            self.log_output(f"DEBUG: Error loading config: {e}")
            return {}

    def detect_arch(self):
        # Try to detect WSL arch from host
        try:
            ret, out, err = self.run_command(['wsl', 'uname', '-m'])
            if ret == 0:
                if 'aarch64' in out:
                    return 'arm64'
                elif 'x86_64' in out:
                    return 'amd64'
            # Fallback to host arch
            if platform.machine().lower() in ['amd64', 'x86_64']:
                return 'amd64'
            elif platform.machine().lower() in ['arm64', 'aarch64']:
                return 'arm64'
        except Exception:
            pass
        return 'amd64'  # Default

    def get_deb_url(self):
        # Template URL will be replaced during build with actual config.yaml value
        template_url = "{{DEB_FILE_URL}}"
        self.log_output(f"Using build-injected deb URL: {template_url}")
        return template_url

    def get_deb_filename(self):
        # Template filename will be extracted from URL during build
        template_url = "{{DEB_FILE_URL}}"
        filename = template_url.split('/')[-1]
        self.log_output(f"Using build-injected deb filename: {filename}")
        return filename
    
    def create_dedicated_wsl_instance(self):
        """Create a dedicated WSL instance for this Kamiwaza version"""
        instance_name = f"kamiwaza-{self.kamiwaza_version}"
        self.log_output(f"Creating dedicated WSL instance: {instance_name}")
        
        # Check if instance already exists
        ret, out, err = self.run_command(['wsl', '--list', '--quiet'], timeout=15)
        if ret == 0 and instance_name in out:
            self.log_output(f"WSL instance {instance_name} already exists")
            return instance_name
        
        # Find a source Ubuntu distribution to clone from
        source_distro = None
        for distro in ['Ubuntu-24.04', 'Ubuntu-22.04', 'Ubuntu']:
            test_ret, _, _ = self.run_command(['wsl', '-d', distro, 'echo', 'test'], timeout=10)
            if test_ret == 0:
                source_distro = distro
                break
        
        if not source_distro:
            self.log_output("ERROR: No Ubuntu distribution found to create dedicated instance")
            return None
        
        self.log_output(f"Using {source_distro} as source for dedicated instance")
        
        # Export source distribution to temp tar file
        import tempfile
        temp_dir = tempfile.gettempdir()
        tar_path = os.path.join(temp_dir, f"{instance_name}.tar")
        
        self.log_output(f"Exporting {source_distro} to {tar_path}...")
        ret, out, err = self.run_command(['wsl', '--export', source_distro, tar_path], timeout=180)
        if ret != 0:
            self.log_output(f"Failed to export {source_distro}: {err}")
            return None
        
        # Create dedicated WSL directory
        wsl_dir = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'WSL', instance_name)
        os.makedirs(wsl_dir, exist_ok=True)
        
        # Import as new dedicated instance
        self.log_output(f"Creating dedicated instance {instance_name}...")
        ret, out, err = self.run_command(['wsl', '--import', instance_name, wsl_dir, tar_path], timeout=180)
        
        # Clean up temp tar file
        try:
            os.remove(tar_path)
        except:
            pass
        
        if ret != 0:
            self.log_output(f"Failed to create dedicated instance: {err}")
            return None
        
        # Test the new instance
        test_ret, _, _ = self.run_command(['wsl', '-d', instance_name, 'echo', 'test'], timeout=15)
        if test_ret == 0:
            self.log_output(f"Successfully created dedicated WSL instance: {instance_name}")
            return instance_name
        else:
            self.log_output(f"Dedicated instance {instance_name} creation failed verification")
            return None

    def get_wsl_distribution(self):
        """Get or create dedicated WSL distribution for this Kamiwaza version"""
        # Try to create/use dedicated instance first
        dedicated_instance = self.create_dedicated_wsl_instance()
        if dedicated_instance:
            self.log_output(f"Using dedicated WSL instance: {dedicated_instance}")
            return ['wsl', '-d', dedicated_instance]
        
        # Fallback to existing logic if dedicated instance fails
        self.log_output("Falling back to existing WSL distributions...")
        
        # Prioritize Ubuntu-24.04 first
        test_ret, _, _ = self.run_command(['wsl', '-d', 'Ubuntu-24.04', 'echo', 'test'], timeout=15)
        if test_ret == 0:
            self.log_output("Using Ubuntu-24.04 distribution for all WSL operations")
            return ['wsl', '-d', 'Ubuntu-24.04']
        
        self.log_output("Ubuntu-24.04 not responding, trying other distributions...")
        # Try other Ubuntu distributions in order of preference
        for distro in ['Ubuntu-22.04', 'Ubuntu']:
            test_ret, _, _ = self.run_command(['wsl', '-d', distro, 'echo', 'test'], timeout=10)
            if test_ret == 0:
                self.log_output(f"Using {distro} distribution for all WSL operations")
                return ['wsl', '-d', distro]
        
        # Last resort - use default WSL (which might be jammy)
        self.log_output("WARNING: Using default WSL distribution - this might not be Ubuntu-24.04!")
        return ['wsl']

    def configure_debconf(self):
        """Pre-configure debconf with user inputs from MSI"""
        try:
            self.log_output("Configuring debconf with user inputs...")
            
            # Set debconf to noninteractive mode to avoid frontend issues
            debconf_env_cmd = "export DEBIAN_FRONTEND=noninteractive"
            
            # Always accept license agreement in unattended mode
            license_cmd = f"{debconf_env_cmd} && echo 'kamiwaza kamiwaza/license_agreement boolean true' | sudo debconf-set-selections"
            self.run_command(self.wsl_distro_cmd + ['bash', '-c', license_cmd], timeout=10)
            
            # Configure user email if provided
            if self.user_email:
                email_cmd = f"{debconf_env_cmd} && echo 'kamiwaza kamiwaza/user_email string {self.user_email}' | sudo debconf-set-selections"
                self.run_command(self.wsl_distro_cmd + ['bash', '-c', email_cmd], timeout=10)
                self.log_output(f"Set user email: {self.user_email}")
            
            # Configure license key if provided
            if self.license_key:
                license_key_cmd = f"{debconf_env_cmd} && echo 'kamiwaza kamiwaza/license_key string {self.license_key}' | sudo debconf-set-selections"
                self.run_command(self.wsl_distro_cmd + ['bash', '-c', license_key_cmd], timeout=10)
                self.log_output("Set license key: [REDACTED]")
            
            # Configure usage reporting (default to enabled if not specified)
            usage_reporting_value = "true" if self.usage_reporting != "0" else "false"
            usage_cmd = f"{debconf_env_cmd} && echo 'kamiwaza kamiwaza/usage_reporting boolean {usage_reporting_value}' | sudo debconf-set-selections"
            self.run_command(self.wsl_distro_cmd + ['bash', '-c', usage_cmd], timeout=10)
            self.log_output(f"Set usage reporting: {usage_reporting_value}")
            
            # Configure install mode (default to lite if not specified)
            mode_value = self.install_mode or "lite"
            mode_cmd = f"{debconf_env_cmd} && echo 'kamiwaza kamiwaza/mode string {mode_value}' | sudo debconf-set-selections"
            self.run_command(self.wsl_distro_cmd + ['bash', '-c', mode_cmd], timeout=10)
            self.log_output(f"Set install mode: {mode_value}")
            
            self.log_output("[OK] Debconf configuration completed")
            
        except Exception as e:
            self.log_output(f"Warning: Error configuring debconf: {e}")
            self.log_output("Continuing with installation anyway...")

    def disable_ipv6_wsl(self):
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
                ret, out, err = self.run_command(self.wsl_distro_cmd + ['bash', '-c', command], timeout=30)
                
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
            ret, out, err = self.run_command(self.wsl_distro_cmd + ['bash', '-c', grub_cmd], timeout=60)
            if ret == 0:
                self.log_output("  [OK] GRUB configured to disable IPv6 at boot")
            else:
                self.log_output("  [WARNING] GRUB IPv6 disable configuration failed (this is normal in WSL)")
            
            self.log_output("[OK] IPv6 disabling completed")
            
        except Exception as e:
            self.log_output(f"Warning: Error disabling IPv6: {e}")
            self.log_output("Continuing with installation anyway...")

    def cleanup_existing_kamiwaza(self):
        """Remove any existing Kamiwaza installation to ensure fresh install"""
        try:
            # Check if kamiwaza package is installed
            check_cmd = "dpkg -l | grep kamiwaza"
            ret, out, err = self.run_command(self.wsl_distro_cmd + ['bash', '-c', check_cmd], timeout=10)
            
            if ret == 0 and 'kamiwaza' in out.lower():
                self.log_output("Found existing Kamiwaza installation. Removing it for fresh install...")
                
                # Stop any running kamiwaza processes first
                stop_cmd = "sudo pkill -f kamiwaza || true"
                self.run_command(self.wsl_distro_cmd + ['bash', '-c', stop_cmd], timeout=10)
                
                # Remove the package with purge flag to remove config files too
                remove_cmd = "sudo apt remove --purge -y kamiwaza"
                ret, out, err = self.run_command(self.wsl_distro_cmd + ['bash', '-c', remove_cmd], real_time=True, timeout=120)
                
                if ret == 0:
                    self.log_output("[OK] Existing Kamiwaza installation removed successfully")
                else:
                    self.log_output(f"Warning: Failed to remove existing Kamiwaza (exit code {ret})")
                    self.log_output("Continuing with installation anyway...")
                
                # Clean up any remaining files
                cleanup_cmd = "sudo rm -rf /opt/kamiwaza /etc/kamiwaza /var/log/kamiwaza || true"
                self.run_command(self.wsl_distro_cmd + ['bash', '-c', cleanup_cmd], timeout=10)
                
            else:
                self.log_output("No existing Kamiwaza installation found. Proceeding with fresh installation.")
                
        except Exception as e:
            self.log_output(f"Warning: Error during cleanup check: {e}")
            self.log_output("Continuing with installation anyway...")

    def start_installation(self):
        self.install_button.config(state='disabled')
        Thread(target=self.perform_installation).start()

    def perform_installation(self):
        try:
            if self.test_mode:
                self.log_output("=== TEST MODE ENABLED ===")
                self.log_output("This is a test run - no actual installation will be performed")
            
            # Determine WSL distribution early to use consistently throughout
            self.status_label.config(text="Setting up dedicated WSL environment...")
            self.log_output("Setting up dedicated WSL environment...")
            self.update_progress(2)
            self.wsl_distro_cmd = self.get_wsl_distribution()
            
            # 0. Configure WSL memory
            self.status_label.config(text="Configuring WSL memory...")
            self.log_output("Configuring WSL memory allocation...")
            self.update_progress(5)
            self.configure_wsl_memory()  # Always try, but only logs if not admin

            # 1. Check for WSL and Windows Server
            self.status_label.config(text="Checking system environment...")
            self.log_output("Checking for Windows Server and WSL...")
            self.update_progress(10)
            is_server = self.is_windows_server()
            if is_server:
                self.log_output("Windows Server detected. Using PowerShell installation method...")
                # Only try to install Ubuntu if admin
                if not is_windows_admin():
                    self.log_output("Administrator privileges are required to install WSL/Ubuntu on Windows Server. Please re-run this installer as administrator if you need to install WSL.")
                    messagebox.showerror(
                        "Administrator Privileges Required",
                        "Administrator privileges are required to install WSL/Ubuntu on Windows Server.\n\n"
                        "Please re-run this installer as administrator if you need to install WSL."
                    )
                    return
                if not self.install_ubuntu_server():
                    raise Exception("Failed to install Ubuntu on Windows Server.")
            else:
                self.log_output("Standard Windows detected. Using regular WSL installation...")
                # More robust WSL detection - try multiple methods
                wsl_working = False
                
                # Method 1: Check wsl --status
                ret, out, err = self.run_command(['wsl', '--status'])
                if ret == 0:
                    wsl_working = True
                    self.log_output("WSL is present (detected via wsl --status).")
                else:
                    self.log_output("wsl --status failed, trying alternative detection methods...")
                
                # Method 2: Try to run a simple command in WSL
                if not wsl_working:
                    ret, out, err = self.run_command(['wsl', 'echo', 'test'], timeout=10)
                    if ret == 0 and 'test' in out:
                        wsl_working = True
                        self.log_output("WSL is present (detected via wsl echo test).")
                
                # Method 3: Try to run a command in Ubuntu-24.04 specifically
                if not wsl_working:
                    ret, out, err = self.run_command(['wsl', '-d', 'Ubuntu-24.04', 'echo', 'test'], timeout=10)
                    if ret == 0 and 'test' in out:
                        wsl_working = True
                        self.log_output("WSL is present (detected via wsl -d Ubuntu-24.04).")
                
                # Method 4: Try to list WSL distributions
                if not wsl_working:
                    ret, out, err = self.run_command(['wsl', '--list', '--verbose'], timeout=10)
                    if ret == 0 and ('Ubuntu' in out or 'ubuntu' in out.lower()):
                        wsl_working = True
                        self.log_output("WSL is present (detected via wsl --list --verbose).")
                
                if not wsl_working:
                    # Only try to install WSL if admin
                    if not is_windows_admin():
                        self.log_output("WSL is not installed and administrator privileges are required to install it. Please install WSL manually as administrator, then re-run this installer.")
                        messagebox.showerror(
                            "WSL Not Installed",
                            "WSL is not installed and administrator privileges are required to install it.\n\n"
                            "Please install WSL manually as administrator, then re-run this installer."
                        )
                        return
                    self.status_label.config(text="Installing WSL...")
                    self.log_output("WSL not found. Attempting to install WSL...")
                    self.update_progress(20)
                    ret, out, err = self.run_command(['wsl', '--install'])
                    if ret != 0:
                        raise Exception("Failed to install WSL. Please install it manually and try again.")
                    self.log_output("WSL installed. Please reboot if this is your first time installing WSL.")
                else:
                    self.log_output("WSL is present and working.")

            # 2. Check for existing Kamiwaza installation and remove it
            self.status_label.config(text="Checking for existing Kamiwaza installation...")
            self.log_output("Checking for existing Kamiwaza installation...")
            self.update_progress(25)
            self.cleanup_existing_kamiwaza()

            # 3. Configure debconf with user inputs from MSI
            self.status_label.config(text="Configuring installation preferences...")
            self.log_output("Configuring debconf with user preferences...")
            self.update_progress(35)
            self.configure_debconf()

            # 3.5. Disable IPv6 in WSL for better network compatibility
            self.status_label.config(text="Configuring network settings...")
            self.log_output("Disabling IPv6 in WSL for better network compatibility...")
            self.update_progress(40)
            self.disable_ipv6_wsl()

            # 4. Download the .deb directly into /tmp in WSL
            self.status_label.config(text="Downloading Kamiwaza package...")
            self.log_output("Downloading .deb package directly into /tmp in WSL...")
            self.update_progress(45)
            deb_url = self.get_deb_url()
            deb_filename = self.get_deb_filename()
            deb_path_wsl = f"/tmp/{deb_filename}"
            deb_path_win = f"\\\\wsl.localhost\\Ubuntu-24.04\\tmp\\{deb_filename}"

            # Test WSL network connectivity with longer timeout
            self.log_output("Testing WSL network connectivity...")
            ret, out, err = self.run_command(self.wsl_distro_cmd + ['bash', '-c', 'ping -c 2 8.8.8.8'], timeout=15)
            if ret != 0:
                self.log_output("WSL network connectivity issue detected. Restarting WSL...")
                self.run_command(['wsl', '--shutdown'], timeout=15)
                import time
                time.sleep(5)
                self.log_output("WSL restarted. Testing connectivity again...")
                ret, out, err = self.run_command(self.wsl_distro_cmd + ['bash', '-c', 'ping -c 2 8.8.8.8'], timeout=15)
                if ret != 0:
                    self.log_output("WSL still has network issues. This may affect downloads.")
                else:
                    self.log_output("WSL network connectivity restored.")
            else:
                self.log_output("WSL network connectivity OK.")

            # Download .deb in WSL /tmp with proper timeout
            download_success = False
            self.log_output("Attempting download with wget in WSL /tmp...")
            download_cmd = f"timeout 300 wget --timeout=60 --tries=3 --user-agent='Mozilla/5.0 (Linux; Ubuntu)' {deb_url} -O {deb_path_wsl}"
            ret, out, err = self.run_command(self.wsl_distro_cmd + ['bash', '-c', download_cmd], timeout=360)
            if ret == 0:
                download_success = True
                self.log_output("Download successful with wget")
            if not download_success:
                self.log_output("wget failed, trying curl in WSL /tmp...")
                download_cmd = f"timeout 300 curl --connect-timeout 60 --max-time 300 -L -A 'Mozilla/5.0 (Linux; Ubuntu)' {deb_url} -o {deb_path_wsl}"
                ret, out, err = self.run_command(self.wsl_distro_cmd + ['bash', '-c', download_cmd])
                if ret == 0:
                    download_success = True
                    self.log_output("Download successful with curl")
            if not download_success:
                self.log_output("Both download methods failed. Trying to restart WSL and retry...")
                try:
                    self.log_output("Restarting WSL...")
                    self.run_command(['wsl', '--shutdown'])
                    import time
                    time.sleep(3)
                    self.log_output("Retrying wget after WSL restart...")
                    download_cmd = f"wget --timeout=120 --tries=2 --user-agent='Mozilla/5.0 (Linux; Ubuntu)' {deb_url} -O {deb_path_wsl}"
                    ret, out, err = self.run_command(self.wsl_distro_cmd + ['bash', '-c', download_cmd])
                    if ret == 0:
                        download_success = True
                        self.log_output("Download successful after WSL restart")
                except Exception as e:
                    self.log_output(f"WSL restart method failed: {e}")
            if not download_success:
                raise Exception("Failed to download .deb package using all methods.")
            self.log_output(".deb download complete in WSL /tmp.")

            # Check if .deb exists in WSL /tmp
            check_deb_cmd = f"[ -f {deb_path_wsl} ]"
            ret, _, _ = self.run_command(self.wsl_distro_cmd + ['bash', '-c', check_deb_cmd], timeout=10)
            if ret != 0:
                raise Exception(f".deb file not found in WSL /tmp at {deb_path_wsl}. Aborting install.")

            # 3. Install the .deb in WSL using proper sudo commands
            self.status_label.config(text="Installing Kamiwaza in WSL...")
            self.log_output("Installing .deb package in WSL...")
            self.update_progress(65)
            
            # Use the WSL distribution determined at the start
            wsl_distro_cmd = self.wsl_distro_cmd
            
            commands = [
                ("Configuring dpkg...", f"export DEBIAN_FRONTEND=noninteractive && sudo -E dpkg --configure -a"),
                ("Installing python3-requests...", f"export DEBIAN_FRONTEND=noninteractive && sudo -E apt-get install --reinstall -y python3-requests || true"),
                ("Fixing broken packages...", f"export DEBIAN_FRONTEND=noninteractive && sudo -E apt-get install -f -y || true"),
                ("Updating package lists...", f"export DEBIAN_FRONTEND=noninteractive && sudo -E apt update"),
                ("Installing Kamiwaza package...", f"export DEBIAN_FRONTEND=noninteractive && sudo -E apt install -f -y {deb_path_wsl}"),
                ("Waiting for package installation to complete...", f"sleep 5"),
                ("Final dpkg configuration...", f"export DEBIAN_FRONTEND=noninteractive && sudo -E dpkg --configure -a"),
                ("Final package fix...", f"export DEBIAN_FRONTEND=noninteractive && sudo -E apt-get install -f -y || true"),
                ("Cleaning up...", f"rm {deb_path_wsl}")
            ]
            
            for i, (description, command) in enumerate(commands):
                self.log_output(f"\n=== {description} ===")
                progress = 65 + (i * 3)
                self.update_progress(progress)
                
                # Use real-time output for apt and dpkg commands
                use_realtime = any(cmd in command for cmd in ['apt', 'dpkg'])
                full_command = wsl_distro_cmd + ['bash', '-c', command]
                
                ret, out, err = self.run_command(full_command, real_time=use_realtime, timeout=300)
                
                if ret != 0 and not command.endswith("|| true"):
                    self.log_output(f"Warning: {description} failed with exit code {ret}")
                    if err:
                        self.log_output(f"Error: {err}")
                else:
                    self.log_output(f"[OK] {description} completed successfully")
            self.log_output("\n.deb install complete.")
            self.log_output(f"\nPost-Installation Details:\n- Kamiwaza is located at /opt/kamiwaza/kamiwaza\n- A 'kamiwaza' user will be created if not present.\n- WSL memory allocation configured to {self.memory} in C:\\wslconfig\n\nTo start Kamiwaza:\n    su kamiwaza\n    kamiwaza start\n")
            self.update_progress(100)
            self.status_label.config(text="Installation completed successfully!")
            self.log_output("Installation finished successfully!")
            
            # Bring window to front before showing success message
            self.bring_to_front()
            messagebox.showinfo("Success", "Kamiwaza has been successfully deployed in WSL Ubuntu!")
            self.close_button.pack()
            self.launch_shell_button.pack()
            
            # Stop the periodic window focusing after installation completes
            try:
                self.after_cancel(self.focus_job)
            except:
                pass
        except Exception as e:
            self.status_label.config(text="Installation failed!")
            self.log_output(f"Error: {str(e)}")
            
            # Bring window to front before showing error message
            self.bring_to_front()
            messagebox.showerror("Installation Error", f"An error occurred:\n{str(e)}")
            self.close_button.pack()
            
            # Stop the periodic window focusing after installation fails
            try:
                self.after_cancel(self.focus_job)
            except:
                pass
        finally:
            self.install_button.config(state='normal')

    def destroy(self):
        if self.debug and self.log_file is not None:
            try:
                self.log_file.close()
            except (OSError, IOError):
                pass  # Ignore errors when closing log file
        super().destroy()

    def show_log_file(self):
        if os.path.exists(self.log_file_path):
            with open(self.log_file_path, "r", encoding="utf-8") as f:
                log_content = f.read()
            self.log_text.delete(1.0, tk.END)
            self.log_text.insert(tk.END, log_content)

    def launch_ubuntu_shell(self):
        try:
            # First, try to launch the dedicated Kamiwaza instance if it exists
            dedicated_instance = f"kamiwaza-{self.kamiwaza_version}"
            ret, _, _ = self.run_command(['wsl', '-d', dedicated_instance, 'echo', 'test'], timeout=10)
            if ret == 0:
                self.log_output(f"Launching dedicated Kamiwaza instance: {dedicated_instance}")
                subprocess.Popen(['wsl', '-d', dedicated_instance])
                return
            
            # Fallback to finding available Ubuntu distributions
            self.log_output("DEBUG: Checking available WSL distributions...")
            ret, out, err = self.run_command(['wsl', '--list', '--verbose'])
            
            # Clean up Unicode null bytes from WSL output
            if out:
                out = out.replace('\x00', '')
            
            if ret == 0:
                self.log_output(f"DEBUG: Available distributions raw output:\n'{out}'")
                
                # Look for Ubuntu Noble first, then any Ubuntu distribution
                lines = out.split('\n')
                ubuntu_distros = []
                noble_distros = []
                for line in lines:
                    line = line.strip()
                    if not line or line.startswith('NAME'):
                        continue
                    # Remove asterisk and extra whitespace
                    if line.startswith('*'):
                        line = line[1:].strip()
                    if 'Ubuntu' in line:
                        parts = line.split()
                        if len(parts) >= 1:
                            distro_name = parts[0]
                            if '24.04' in distro_name or 'noble' in distro_name.lower():
                                noble_distros.append(distro_name)
                            else:
                                ubuntu_distros.append(distro_name)
                            self.log_output(f"DEBUG: Found Ubuntu distribution: {distro_name}")
                
                # Use Noble first, then any Ubuntu
                target_distro = None
                if noble_distros:
                    target_distro = noble_distros[0]
                    self.log_output(f"Launching WSL distribution: {target_distro}")
                elif ubuntu_distros:
                    target_distro = ubuntu_distros[0]
                    self.log_output(f"Launching WSL distribution: {target_distro}")
                
                if target_distro:
                    # Test if the distribution is working before launching
                    ret, _, _ = self.run_command(['wsl', '-d', target_distro, 'echo', 'test'], timeout=15)
                    if ret == 0:
                        subprocess.Popen(["wsl", "-d", target_distro])
                    else:
                        self.log_output(f"Distribution {target_distro} not responding, trying to restart WSL...")
                        self.run_command(['wsl', '--shutdown'], timeout=15)
                        import time
                        time.sleep(5)
                        
                        # Try again after restart
                        ret, _, _ = self.run_command(['wsl', '-d', target_distro, 'echo', 'test'], timeout=15)
                        if ret == 0:
                            subprocess.Popen(["wsl", "-d", target_distro])
                        else:
                            self.log_output(f"Distribution {target_distro} still not responding after restart")
                            # Try launching default WSL anyway
                            subprocess.Popen(["wsl"])
                else:
                    # Fallback to default WSL
                    self.log_output("DEBUG: No Ubuntu distributions found, using default WSL")
                    subprocess.Popen(["wsl"])
            else:
                # Fallback to default WSL if list command fails
                self.log_output("DEBUG: Could not list WSL distributions, using default")
                subprocess.Popen(["wsl"])
                
        except Exception as e:
            messagebox.showerror("Error", f"Failed to launch Ubuntu shell:\n{e}")

    def try_configure_passwordless_sudo_wsl(self, on_success=None, on_failure=None):
        self.log_output("Attempting to configure passwordless sudo for 'kamiwaza' user in WSL...")
        
        def show_manual_sudo_instructions():
            instructions = (
                "Passwordless sudo is not configured for the 'kamiwaza' user in WSL.\n\n"
                "Please run the following commands in the WSL terminal to enable it:\n\n"
                "    sudo useradd -m -s /bin/bash kamiwaza  # if not already present\n"
                "    echo 'kamiwaza ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/kamiwaza\n"
                "    sudo chmod 0440 /etc/sudoers.d/kamiwaza\n"
                "    sudo chown root:root /etc/sudoers.d/kamiwaza\n\n"
                "After running these, click Retry below."
            )
            self.log_output("Manual intervention required for passwordless sudo. Opening WSL terminal for user.")
            # Open WSL terminal
            try:
                subprocess.Popen(self.get_wsl_distribution())
            except Exception as e:
                self.log_output(f"Failed to open WSL terminal: {e}")
            # Show instructions and Retry button
            def on_retry():
                if has_passwordless_sudo_wsl():
                    self.log_output("Passwordless sudo now detected. Continuing installation.")
                    retry_win.destroy()
                    if on_success:
                        self.after(100, on_success)
                else:
                    messagebox.showerror("Still Not Configured", "Passwordless sudo is still not configured. Please try again.")
            retry_win = tk.Toplevel(self)
            retry_win.title("Manual Sudo Configuration Required")
            # Use a Text widget for copyable instructions
            text_widget = tk.Text(retry_win, height=12, width=70, wrap="word")
            text_widget.insert(tk.END, instructions)
            text_widget.config(state="normal")  # Allow selection/copy
            text_widget.config(state="disabled")  # Prevent editing
            text_widget.pack(padx=20, pady=20)
            tk.Button(retry_win, text="Retry", command=on_retry).pack(pady=10)
            retry_win.grab_set()
            retry_win.lift()
            retry_win.focus_force()

        try:
            # Use the same WSL distribution we'll use for installation
            wsl_cmd = self.get_wsl_distribution()
            
            # 1. Ensure kamiwaza user exists
            create_user_cmd = "id -u kamiwaza || sudo useradd -m -s /bin/bash kamiwaza"
            ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', create_user_cmd], timeout=30)
            if ret != 0:
                self.log_output("Failed to create 'kamiwaza' user or user already exists.")
            # 2. Add passwordless sudo using a more reliable method
            sudoers_line = "kamiwaza ALL=(ALL) NOPASSWD:ALL"
            temp_file_cmd = f"echo '{sudoers_line}' > /tmp/kamiwaza_sudoers"
            ret1, _, _ = self.run_command(wsl_cmd + ['bash', '-c', temp_file_cmd], timeout=10)
            if ret1 == 0:
                move_cmd = "sudo cp /tmp/kamiwaza_sudoers /etc/sudoers.d/kamiwaza && sudo chmod 0440 /etc/sudoers.d/kamiwaza && sudo chown root:root /etc/sudoers.d/kamiwaza && rm -f /tmp/kamiwaza_sudoers"
                ret2, out, err = self.run_command(wsl_cmd + ['bash', '-c', move_cmd], timeout=30)
                if ret2 == 0:
                    self.log_output("Passwordless sudo configured for 'kamiwaza' user in WSL.")
                    if on_success:
                        self.after(100, on_success)
                    return True
                else:
                    self.log_output(f"Failed to configure passwordless sudo: {err}")
                    show_manual_sudo_instructions()
                    return False
            else:
                self.log_output("Failed to create temporary sudoers file.")
                show_manual_sudo_instructions()
                return False
        except Exception as e:
            self.log_output(f"Exception during sudo configuration: {e}")
            show_manual_sudo_instructions()
            return False

if __name__ == "__main__":
    # Set up proper stdout/stderr for GUI context
    import sys
    if sys.stdout is None:
        sys.stdout = open(os.devnull, 'w')
    if sys.stderr is None:
        sys.stderr = open(os.devnull, 'w')

    try:
        parser = argparse.ArgumentParser(description='Kamiwaza WSL Installer')
        parser.add_argument('--debug', action='store_true', help='Enable debug mode')
        parser.add_argument('--memory', default='14GB', help='WSL memory allocation (e.g., 8GB, 14GB, 16GB)')
        parser.add_argument('--version', help='Kamiwaza version')
        parser.add_argument('--codename', help='Ubuntu codename')
        parser.add_argument('--build', help='Build number')
        parser.add_argument('--arch', help='Architecture')
        parser.add_argument('--email', help='User email')
        parser.add_argument('--license-key', help='License key')
        parser.add_argument('--usage-reporting', help='Usage reporting preference')
        parser.add_argument('--mode', help='Installation mode')
        parser.add_argument('--test', action='store_true', help='Enable test mode (skip actual installation)')
        args = parser.parse_args()
        
        print(f"DEBUG: Arguments parsed: email={args.email}, license_key={'[SET]' if args.license_key else '[NOT SET]'}, usage_reporting={args.usage_reporting}, mode={args.mode}")
        
        app = KamiwazaInstaller(
            debug=args.debug, 
            memory=args.memory,
            version=args.version,
            codename=args.codename,
            build=args.build,
            arch=args.arch,
            test_mode=args.test,
            user_email=args.email,
            license_key=args.license_key,
            usage_reporting=args.usage_reporting,
            install_mode=args.mode
        )
    except (SystemExit, AttributeError):
        # Handle argparse errors in GUI mode
        app = KamiwazaInstaller(debug=False, memory='14GB')
    except Exception as e:
        # Fallback for any other errors
        try:
            app = KamiwazaInstaller(debug=True, memory='14GB')
        except Exception as fallback_error:
            # Last resort - create minimal app
            import tkinter as tk
            root = tk.Tk()
            root.title("Kamiwaza Installer - Error")
            error_label = tk.Label(root, text=f"Failed to start installer:\n{str(e)}\n\nFallback error:\n{str(fallback_error)}")
            error_label.pack(padx=20, pady=20)
            root.mainloop()
            sys.exit(1)
    app.mainloop() 

# --- INSIDE KamiwazaInstaller ---
# Patch perform_installation and configure_wsl_memory to only require admin if needed

# In perform_installation, before running any admin-required step (like DISM), check is_windows_admin().
# If not admin and WSL is missing, show a message and abort. If WSL is present, proceed as normal user.
# In configure_wsl_memory, if not admin, just log and skip, do not show a warning popup. 
