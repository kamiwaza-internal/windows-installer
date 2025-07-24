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
    def __init__(self, debug=False, memory="14GB", config_path="config.yaml", version=None, codename=None, build=None, arch=None):
        super().__init__()
        self.title("Kamiwaza Installer")
        self.geometry("600x400")
        self.debug = debug
        self.memory = memory
        self.log_file_path = get_log_file_path()
        # Always-on logging
        try:
            self.log_file = open(self.log_file_path, "a", encoding="utf-8")
        except (PermissionError, OSError) as e:
            print(f"Warning: Could not create log file: {e}")
            self.log_file = None

        # Load config
        self.config = self.load_config(config_path)
        self.kamiwaza_version = version or self.config.get('kamiwaza_version', '0.5.0-rc1')
        self.codename = codename or self.config.get('codename', 'noble')
        self.build_number = build or self.config.get('build_number', 1)
        self.arch = arch or self.config.get('arch', 'auto')
        if self.arch == 'auto':
            self.arch = self.detect_arch()

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
        self.after(500, self.start_installation)

        # Show log button
        if self.debug:
            self.show_log_button = ttk.Button(self, text="Show Log File", command=self.show_log_file)
            self.show_log_button.pack(pady=5)

        # Enforce WSL sudo check at start, but try to auto-configure if missing
        if not has_passwordless_sudo_wsl():
            if not self.try_configure_passwordless_sudo_wsl():
                self.log_output("Warning: Passwordless sudo is not configured for user kamiwaza in WSL. The .deb installer will attempt to proceed, but you may be prompted for a password or encounter permission issues.")
                # Do NOT exit; just continue

    def log_output(self, message):
        import datetime
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_line = f"[{timestamp}] {message}"
        self.log_text.insert(tk.END, log_line + "\n")
        self.log_text.see(tk.END)
        self.update()
        try:
            if self.log_file is not None:
                self.log_file.write(log_line + "\n")
                self.log_file.flush()
        except (OSError, IOError):
            self.log_file = None
        log_with_timestamp(message)

    def update_progress(self, value):
        self.progress_var.set(value)
        self.update()

    def run_command(self, command, real_time=False, timeout=None):
        self.log_output(f"Running: {' '.join(command)}")
        try:
            # Ensure UTF-8 output from subprocess
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "UTF-8"
            
            if real_time:
                # For real-time output (like apt install)
                process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, 
                                         text=True, encoding='utf-8', env=env, bufsize=1, universal_newlines=True)
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
                # Original method for quick commands
                process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8', env=env)
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
        """Configure WSL memory allocation in .wslconfig file"""
        if not is_windows_admin():
            self.log_output("Administrator privileges are required to configure WSL memory. Skipping this step.")
            messagebox.showwarning("Administrator Privileges Required", "Administrator privileges are required to configure WSL memory. This step will be skipped.")
            return False
        try:
            self.log_output(f"Configuring WSL memory allocation to {self.memory}...")
            wslconfig_path = os.path.expanduser("~\\.wslconfig")
            config_content = f"""[wsl2]\nmemory={self.memory}\nprocessors=auto\nswap=0\nlocalhostForwarding=true\nnetworkingMode=mirrored\n"""
            with open(wslconfig_path, 'w') as f:
                f.write(config_content)
            self.log_output(f"Successfully configured .wslconfig at {wslconfig_path}")
            self.log_output(f"Memory allocation set to: {self.memory}")
            return True
        except Exception as e:
            self.log_output(f"Error configuring .wslconfig: {e}")
            self.log_output("This is not critical - WSL will use default settings.")
            return False

    def load_config(self, config_path):
        try:
            with open(config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception:
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
        return f"https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/kamiwaza_{self.kamiwaza_version}_{self.codename}_{self.arch}_build{self.build_number}.deb"

    def get_deb_filename(self):
        return f"kamiwaza_{self.kamiwaza_version}_{self.codename}_{self.arch}_build{self.build_number}.deb"

    def start_installation(self):
        self.install_button.config(state='disabled')
        Thread(target=self.perform_installation).start()

    def perform_installation(self):
        try:
            # 0. Configure WSL memory
            self.status_label.config(text="Configuring WSL memory...")
            self.log_output("Configuring WSL memory allocation...")
            self.update_progress(5)
            if not self.configure_wsl_memory():
                self.log_output("Warning: Failed to configure WSL memory. Continuing with installation...")

            # 1. Check for WSL
            self.status_label.config(text="Checking for WSL...")
            self.log_output("Checking for WSL...")
            self.update_progress(10)
            ret, out, err = self.run_command(['wsl', '--status'])
            if ret != 0:
                self.status_label.config(text="Installing WSL...")
                self.log_output("WSL not found. Attempting to install WSL...")
                self.update_progress(20)
                ret, out, err = self.run_command(['wsl', '--install'])
                if ret != 0:
                    raise Exception("Failed to install WSL. Please install it manually and try again.")
                self.log_output("WSL installed. Please reboot if this is your first time installing WSL.")
            else:
                self.log_output("WSL is present.")

            # 2. Download the .deb directly into /tmp in WSL
            self.status_label.config(text="Downloading Kamiwaza package...")
            self.log_output("Downloading .deb package directly into /tmp in WSL...")
            self.update_progress(40)
            deb_url = self.get_deb_url()
            deb_filename = self.get_deb_filename()
            deb_path_wsl = f"/tmp/{deb_filename}"
            deb_path_win = f"\\\\wsl.localhost\\Ubuntu-24.04\\tmp\\{deb_filename}"

            # Test WSL network connectivity
            self.log_output("Testing WSL network connectivity...")
            ret, out, err = self.run_command(['wsl', 'bash', '-c', 'ping -c 2 8.8.8.8'])
            if ret != 0:
                self.log_output("WSL network connectivity issue detected. Restarting WSL...")
                self.run_command(['wsl', '--shutdown'])
                import time
                time.sleep(3)
                self.log_output("WSL restarted. Testing connectivity again...")
                ret, out, err = self.run_command(['wsl', 'bash', '-c', 'ping -c 2 8.8.8.8'])
                if ret != 0:
                    self.log_output("WSL still has network issues. This may affect downloads.")
                else:
                    self.log_output("WSL network connectivity restored.")
            else:
                self.log_output("WSL network connectivity OK.")

            # Download .deb in WSL /tmp
            download_success = False
            self.log_output("Attempting download with wget in WSL /tmp...")
            download_cmd = f"timeout 300 wget --timeout=60 --tries=3 --user-agent='Mozilla/5.0 (Linux; Ubuntu)' {deb_url} -O {deb_path_wsl}"
            ret, out, err = self.run_command(['wsl', 'bash', '-c', download_cmd])
            if ret == 0:
                download_success = True
                self.log_output("Download successful with wget")
            if not download_success:
                self.log_output("wget failed, trying curl in WSL /tmp...")
                download_cmd = f"timeout 300 curl --connect-timeout 60 --max-time 300 -L -A 'Mozilla/5.0 (Linux; Ubuntu)' {deb_url} -o {deb_path_wsl}"
                ret, out, err = self.run_command(['wsl', 'bash', '-c', download_cmd])
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
                    ret, out, err = self.run_command(['wsl', 'bash', '-c', download_cmd])
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
            ret, _, _ = self.run_command(['wsl', 'bash', '-c', check_deb_cmd])
            if ret != 0:
                raise Exception(f".deb file not found in WSL /tmp at {deb_path_wsl}. Aborting install.")

            # 3. Install the .deb in WSL (all sudo -n, no password prompts)
            self.status_label.config(text="Installing Kamiwaza in WSL...")
            self.log_output("Updating apt and installing .deb package in WSL...")
            self.update_progress(70)
            commands = [
                ("Configuring dpkg...", f"sudo -n dpkg --configure -a"),
                ("Installing python3-requests...", f"sudo -n apt-get install --reinstall -y python3-requests || true"),
                ("Fixing broken packages...", f"sudo -n apt-get install -f -y || true"),
                ("Updating package lists...", f"sudo -n apt update"),
                ("Installing Kamiwaza package...", f"sudo -n apt install -f -y {deb_path_wsl}"),
                ("Final dpkg configuration...", f"sudo -n dpkg --configure -a"),
                ("Final package fix...", f"sudo -n apt-get install -f -y || true"),
                ("Cleaning up...", f"rm {deb_path_wsl}")
            ]
            for i, (description, command) in enumerate(commands):
                self.log_output(f"\n=== {description} ===")
                progress = 70 + (i * 3)
                self.update_progress(progress)
                use_realtime = any(cmd in command for cmd in ['apt', 'dpkg'])
                ret, out, err = self.run_command(['wsl', 'bash', '-c', command], real_time=use_realtime)
                if ret != 0 and not command.endswith("|| true"):
                    self.log_output(f"Warning: Command failed with exit code {ret}")
                else:
                    self.log_output(f"✓ {description} completed")
            self.log_output("\n.deb install complete.")
            self.log_output(f"\nPost-Installation Details:\n- Kamiwaza is located at /opt/kamiwaza/kamiwaza\n- A 'kamiwaza' user will be created if not present.\n- WSL memory allocation configured to {self.memory} in C:\\wslconfig\n\nTo start Kamiwaza:\n    su kamiwaza\n    kamiwaza start\n")
            self.update_progress(100)
            self.status_label.config(text="Installation completed successfully!")
            self.log_output("Installation finished successfully!")
            messagebox.showinfo("Success", "Kamiwaza has been successfully deployed in WSL Ubuntu!")
            self.close_button.pack()
            self.launch_shell_button.pack()
        except Exception as e:
            self.status_label.config(text="Installation failed!")
            self.log_output(f"Error: {str(e)}")
            messagebox.showerror("Installation Error", f"An error occurred:\n{str(e)}")
            self.close_button.pack()
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
            subprocess.Popen(["wsl"])
        except Exception as e:
            messagebox.showerror("Error", f"Failed to launch Ubuntu shell:\n{e}")

    def try_configure_passwordless_sudo_wsl(self):
        self.log_output("Attempting to configure passwordless sudo for 'kamiwaza' user in WSL...")
        
        try:
            # 1. Ensure kamiwaza user exists
            create_user_cmd = "id -u kamiwaza || sudo useradd -m -s /bin/bash kamiwaza"
            ret, out, err = self.run_command(['wsl', 'bash', '-c', create_user_cmd], timeout=30)
            if ret != 0:
                self.log_output("Failed to create 'kamiwaza' user or user already exists.")
            
            # 2. Add passwordless sudo using a more reliable method
            sudoers_line = "kamiwaza ALL=(ALL) NOPASSWD:ALL"
            
            # Create the sudoers file in a safer way
            temp_file_cmd = f"echo '{sudoers_line}' > /tmp/kamiwaza_sudoers"
            ret1, _, _ = self.run_command(['wsl', 'bash', '-c', temp_file_cmd], timeout=10)
            
            if ret1 == 0:
                # Move the file to sudoers.d with proper permissions
                move_cmd = "sudo cp /tmp/kamiwaza_sudoers /etc/sudoers.d/kamiwaza && sudo chmod 0440 /etc/sudoers.d/kamiwaza && sudo chown root:root /etc/sudoers.d/kamiwaza && rm -f /tmp/kamiwaza_sudoers"
                ret2, out, err = self.run_command(['wsl', 'bash', '-c', move_cmd], timeout=30)
                
                if ret2 == 0:
                    self.log_output("Passwordless sudo configured for 'kamiwaza' user in WSL.")
                    return True
                else:
                    self.log_output(f"Failed to configure passwordless sudo: {err}")
                    return False
            else:
                self.log_output("Failed to create temporary sudoers file.")
                return False
                
        except Exception as e:
            self.log_output(f"Exception during sudo configuration: {e}")
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
        
        args = parser.parse_args()
        
        app = KamiwazaInstaller(
            debug=args.debug, 
            memory=args.memory,
            version=args.version,
            codename=args.codename,
            build=args.build,
            arch=args.arch
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
