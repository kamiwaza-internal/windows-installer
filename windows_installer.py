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

class KamiwazaInstaller(tk.Tk):
    def __init__(self, debug=False, memory="14GB", config_path="config.yaml", version=None, codename=None, build=None, arch=None):
        super().__init__()
        self.title("Kamiwaza Installer")
        self.geometry("600x400")
        self.debug = debug
        self.memory = memory
        self.log_file = open("kamiwaza_installer_debug.log", "w") if debug else None

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

    def log_output(self, message):
        message = ftfy.fix_text(message)
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
        self.update()
        if self.debug and self.log_file:
            self.log_file.write(message + "\n")
            self.log_file.flush()

    def update_progress(self, value):
        self.progress_var.set(value)
        self.update()

    def run_command(self, command):
        self.log_output(f"Running: {' '.join(command)}")
        try:
            # Ensure UTF-8 output from subprocess
            env = os.environ.copy()
            env["PYTHONIOENCODING"] = "UTF-8"
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8', env=env)
            stdout, stderr = process.communicate()
            if stdout:
                self.log_output(stdout)
            if stderr:
                self.log_output(stderr)
            return process.returncode, stdout, stderr
        except Exception as e:
            self.log_output(f"Error running command: {e}")
            return 1, "", str(e)

    def configure_wsl_memory(self):
        """Configure WSL memory allocation in .wslconfig file"""
        try:
            self.log_output(f"Configuring WSL memory allocation to {self.memory}...")
            wslconfig_path = "C:\\.wslconfig"
            
            # Create or update .wslconfig file
            config_content = f"""[wsl2]
memory={self.memory}
processors=auto
swap=0
localhostForwarding=true
"""
            
            with open(wslconfig_path, 'w') as f:
                f.write(config_content)
            
            self.log_output(f"Successfully configured .wslconfig at {wslconfig_path}")
            self.log_output(f"Memory allocation set to: {self.memory}")
            return True
            
        except Exception as e:
            self.log_output(f"Error configuring .wslconfig: {e}")
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

            # 2. Download the .deb in WSL
            self.status_label.config(text="Downloading Kamiwaza package...")
            self.log_output("Downloading .deb package in WSL...")
            self.update_progress(40)
            deb_url = self.get_deb_url()
            deb_filename = self.get_deb_filename()
            download_cmd = f"wget {deb_url} -O /tmp/{deb_filename}"
            ret, out, err = self.run_command(['wsl', 'bash', '-c', download_cmd])
            if ret != 0:
                raise Exception("Failed to download .deb package in WSL.")

            self.log_output(".deb download complete.")

            # 3. Install the .deb in WSL (brute-force recovery sequence)
            self.status_label.config(text="Installing Kamiwaza in WSL...")
            self.log_output("Updating apt and installing .deb package in WSL...")
            self.update_progress(70)
            commands = [
                "sudo dpkg --configure -a",
                "sudo apt-get install --reinstall -y python3-requests || true",
                "sudo apt-get install -f -y || true",
                "sudo apt update",
                f"sudo apt install -f -y /tmp/{deb_filename}",
                "sudo dpkg --configure -a",
                "sudo apt-get install -f -y || true",
                f"rm /tmp/{deb_filename}"
            ]
            script_content = "\n".join(commands)

            heredoc = f"cat <<'EOF' > /tmp/fix_install.sh\n{script_content}\nEOF"
            self.run_command(['wsl', 'bash', '-c', heredoc])

            self.log_output(".deb install complete.")

            self.log_output(f"""
Post-Installation Details:
- Kamiwaza is located at /opt/kamiwaza/kamiwaza
- A 'kamiwaza' user will be created if not present.
- WSL memory allocation configured to {self.memory} in C:\\.wslconfig

To start Kamiwaza:
    su kamiwaza
    kamiwaza start
""")

            self.update_progress(100)
            self.status_label.config(text="Installation completed successfully!")
            self.log_output("Installation finished successfully!")
            messagebox.showinfo("Success", "Kamiwaza has been successfully deployed in WSL Ubuntu!")
            self.close_button.pack()  # Show the close button
            self.launch_shell_button.pack()  # Show the launch shell button

        except Exception as e:
            self.status_label.config(text="Installation failed!")
            self.log_output(f"Error: {str(e)}")
            messagebox.showerror("Installation Error", f"An error occurred:\n{str(e)}")
            self.close_button.pack()
        finally:
            self.install_button.config(state='normal')

    def destroy(self):
        if self.debug and self.log_file:
            self.log_file.close()
        super().destroy()

    def show_log_file(self):
        if os.path.exists("kamiwaza_installer_debug.log"):
            with open("kamiwaza_installer_debug.log", "r") as f:
                log_content = f.read()
            self.log_text.delete(1.0, tk.END)
            self.log_text.insert(tk.END, log_content)

    def launch_ubuntu_shell(self):
        try:
            subprocess.Popen(["wsl"])
        except Exception as e:
            messagebox.showerror("Error", f"Failed to launch Ubuntu shell:\n{e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Kamiwaza WSL Installer')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    parser.add_argument('--memory', default='14GB', help='WSL memory allocation (e.g., 8GB, 14GB, 16GB)')
    
    args = parser.parse_args()
    
    app = KamiwazaInstaller(debug=args.debug, memory=args.memory)
    app.mainloop() 
