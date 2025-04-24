import tkinter as tk
from tkinter import ttk, messagebox
import subprocess
import sys
import os
import requests
from threading import Thread
from PIL import Image, ImageTk
from io import BytesIO
import time
import ctypes
import win32com.shell.shell as shell
import win32event
import win32process
from win32com.shell import shellcon

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def run_as_admin():
    try:
        if is_admin():
            return True

        # Get the path to the current script
        script = os.path.abspath(sys.argv[0])
        
        # Use ctypes to trigger UAC and restart with admin rights
        ctypes.windll.shell32.ShellExecuteW(
            None,                   # Parent handle
            "runas",               # Operation
            sys.executable,        # Program
            f'"{script}"',         # Parameters
            None,                  # Directory
            1                      # Show window
        )
        sys.exit()
        
    except Exception as e:
        messagebox.showerror("Error", f"Failed to restart with administrator privileges:\n{str(e)}")
        return False

# Check and install missing libraries
required_libraries = {
    "requests": "requests>=2.31.0",
    "PIL": "Pillow",
    "acryl-datahub": "acryl-datahub>=0.12.0",
    "pywin32": "pywin32"  # Added requirement for admin check
}

def install_package(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", package])

for lib, package in required_libraries.items():
    try:
        if lib == "PIL":
            __import__("PIL")
        else:
            __import__(lib)
    except ImportError:
        print(f"{lib} not found. Installing...")
        install_package(package)

class KamiwazaInstaller(tk.Tk):
    def __init__(self):
        super().__init__()

        # Verify admin privileges before proceeding
        if not is_admin():
            messagebox.showerror("Error", "This installer must be run as administrator.")
            self.quit()
            return

        self.title("Kamiwaza Installer")
        self.geometry("600x700")
        
        style = ttk.Style()
        style.theme_use('clam')
        
        # Configure colors
        self.configure(bg='#f0f0f0')
        
        # Main frame with padding and scroll
        main_frame = ttk.Frame(self)
        main_frame.pack(padx=20, pady=20, fill='both', expand=True)

        # Top section frame (fixed height)
        top_frame = ttk.Frame(main_frame)
        top_frame.pack(fill='x', pady=(0, 10))

        # Logo
        try:
            response = requests.get("https://cdn.prod.website-files.com/66e19ed2f1ab3456d8af3b6a/66e19ed2f1ab3456d8af3c11_01cc1249-b3a3-429c-9b34-589db931560e%201.png")
            image = Image.open(BytesIO(response.content))
            image = image.resize((200, 100), Image.Resampling.LANCZOS)
            self.logo = ImageTk.PhotoImage(image)
            logo_label = ttk.Label(top_frame, image=self.logo)
            logo_label.pack(pady=10)
        except Exception as e:
            print(f"Could not load logo: {e}")
        
        # Title
        title_label = ttk.Label(
            top_frame,
            text="Kamiwaza Installation",
            font=('Helvetica', 16, 'bold')
        )
        title_label.pack(pady=10)

        # Components frame (fixed height)
        self.components_frame = ttk.LabelFrame(main_frame, text="Components to Install")
        self.components_frame.pack(fill='x', pady=(0, 10))

        # Checkboxes for components
        self.components = {
            'wsl': {'var': tk.BooleanVar(value=True), 'text': 'Windows Subsystem for Linux (WSL)'},
            'docker': {'var': tk.BooleanVar(value=True), 'text': 'Docker Desktop'},
        }

        for key, component in self.components.items():
            cb = ttk.Checkbutton(
                self.components_frame,
                text=component['text'],
                variable=component['var']
            )
            cb.pack(anchor='w', padx=10, pady=5)

        # Progress frame (fixed height)
        progress_frame = ttk.LabelFrame(main_frame, text="Installation Progress")
        progress_frame.pack(fill='x', pady=(0, 10))

        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(
            progress_frame,
            variable=self.progress_var,
            maximum=100
        )
        self.progress_bar.pack(fill='x', padx=10, pady=10)

        # Status labels
        self.status_label = ttk.Label(
            progress_frame,
            text="Ready to install",
            font=('Helvetica', 10),
            foreground='#333333'
        )
        self.status_label.pack(pady=5)

        # Log output frame (smaller, fixed height)
        log_frame = ttk.LabelFrame(main_frame, text="Log Output")
        log_frame.pack(fill='x', pady=(0, 10))

        # Create a frame to contain both the text widget and scrollbar
        log_container = ttk.Frame(log_frame)
        log_container.pack(fill='both', padx=10, pady=10)

        # Add scrollbar
        scrollbar = ttk.Scrollbar(log_container)
        scrollbar.pack(side='right', fill='y')

        # Configure text widget with smaller height and scrollbar
        self.log_text = tk.Text(
            log_container,
            wrap='word',
            height=6,
            yscrollcommand=scrollbar.set,
            font=('Courier', 9)
        )
        self.log_text.pack(side='left', fill='both', expand=True)
        scrollbar.config(command=self.log_text.yview)

        # Buttons frame at the bottom
        button_frame = ttk.Frame(main_frame)
        button_frame.pack(fill='x', pady=(0, 10))

        # Configure button styles
        style.configure('Primary.TButton',
            padding=10,
            background='#4CAF50',
            foreground='white',
            font=('Helvetica', 11, 'bold')
        )
        style.configure('Secondary.TButton',
            padding=10,
            background='#f44336',
            font=('Helvetica', 11)
        )

        # Center the buttons
        button_frame.grid_columnconfigure(0, weight=1)
        button_frame.grid_columnconfigure(3, weight=1)

        self.install_button = ttk.Button(
            button_frame,
            text="Install",
            style='Primary.TButton',
            command=self.start_installation,
            width=20
        )
        self.install_button.grid(row=0, column=1, padx=10)

        self.cancel_button = ttk.Button(
            button_frame,
            text="Cancel",
            style='Secondary.TButton',
            command=self.quit,
            width=20
        )
        self.cancel_button.grid(row=0, column=2, padx=10)

    def update_status(self, message, progress=None):
        self.status_label.config(text=message)
        if progress is not None:
            self.progress_var.set(progress)
        self.update()

    def log_output(self, message):
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
        self.update()

    def run_command(self, command):
        self.log_output(f"Running command: {' '.join(command)}")
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout, stderr = process.communicate()
        self.log_output(stdout)
        self.log_output(stderr)
        return process

    def check_wsl(self):
        try:
            result = self.run_command(['wsl', '--status'])
            return result.returncode == 0
        except:
            return False

    def install_wsl(self):
        self.update_status("Installing Windows Subsystem for Linux...", 5)
        # Enable WSL feature
        self.run_command(['dism.exe', '/online', '/enable-feature', '/featurename:Microsoft-Windows-Subsystem-Linux', '/all', '/norestart'])
        # Enable Virtual Machine Platform
        self.run_command(['dism.exe', '/online', '/enable-feature', '/featurename:VirtualMachinePlatform', '/all', '/norestart'])
        # Download and install WSL2 kernel update
        url = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
        response = requests.get(url)
        with open("wsl_update.msi", "wb") as f:
            f.write(response.content)
        self.run_command(['msiexec', '/i', 'wsl_update.msi', '/quiet'])
        os.remove("wsl_update.msi")
        # Set WSL2 as default
        self.run_command(['wsl', '--set-default-version', '2'])

    def check_docker(self):
        try:
            result = self.run_command(['docker', '--version'])
            return result.returncode == 0
        except:
            return False

    def install_docker(self):
        self.update_status("Installing Docker Desktop...", 30)
        url = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        response = requests.get(url)
        with open("docker_installer.exe", "wb") as f:
            f.write(response.content)
        
        self.run_command(['docker_installer.exe', 'install', '--quiet'])
        os.remove("docker_installer.exe")

    def start_installation(self):
        """Start the installation process including initialization."""
        self.install_button.config(state='disabled')
        Thread(target=self.perform_installation).start()

    def perform_installation(self):
        """Perform the complete installation process."""
        try:
            # Initialize system first
            self.update_status("Checking system requirements...", 0)
            
            # Check WSL status
            self.update_status("Checking WSL status...", 10)
            if not self.check_wsl():
                self.update_status("WSL not found. Installing...", 20)
                self.install_wsl()
            
            # Check Docker status
            self.update_status("Checking Docker status...", 30)
            if not self.check_docker():
                self.update_status("Docker not found. Please install Docker Desktop manually.", 40)
                messagebox.showinfo("Docker Required", "Please install Docker Desktop manually before proceeding.")
            
            # Proceed with Kamiwaza installation
            if self.components['wsl']['var'].get():
                self.update_status("Installing WSL components...", 50)
                # WSL installation logic here
                pass

            if self.components['docker']['var'].get():
                self.update_status("Setting up Docker components...", 70)
                # Docker setup logic here
                pass

            # Deploy Kamiwaza
            user_wants_kamiwaza = messagebox.askyesno(
                "WSL Deployment",
                "Would you like to install Kamiwaza in WSL Ubuntu?"
            )
            
            if user_wants_kamiwaza:
                self.run_wsl_deployment(user_wants_kamiwaza)
            
        except Exception as e:
            messagebox.showerror("Installation Error", f"An error occurred during installation:\n{str(e)}")
            self.update_status("Installation failed", 0)
        finally:
            self.install_button.config(state='normal')

    def run_wsl_deployment(self, user_wants_kamiwaza):
        """Run the Kamiwaza deployment in WSL Ubuntu."""
        try:
            self.update_status("Setting up WSL Ubuntu...", 90)
            
            # Install Ubuntu distribution if not present
            try:
                # Check if Ubuntu is installed
                result = self.run_command(['wsl', '-l'])
                if 'Ubuntu' not in result.stdout:
                    self.update_status("Installing Ubuntu on WSL...", 91)
                    self.run_command(['wsl', '--install', '-d', 'Ubuntu'])
                    messagebox.showinfo("Ubuntu Install", "Ubuntu is being installed. Please wait for it to complete setup and create a user account, then click OK to continue.")
            except Exception as e:
                messagebox.showerror("Error", f"Failed to install Ubuntu: {str(e)}")
                return
                
            self.update_status("Setting up Kamiwaza deployment...", 92)
            
            # Local path to the deployment package
            local_package = "kamiwaza-deploy-full.deb"
            
            # Check if the local package exists
            if not os.path.exists(local_package):
                messagebox.showerror("Error", f"Could not find {local_package} in the current directory.")
                return
                
            # The following code is for future GitHub deployment
            # # Download from GitHub
            # url = "https://github.com/m9e/kamiwaza/releases/latest/download/kamiwaza-deploy-full.deb"
            # response = requests.get(url)
            # with open("kamiwaza-deploy-full.deb", "wb") as f:
            #     f.write(response.content)
                
            self.update_status("Copying package to WSL...", 95)
            
            # Get the WSL user's home path
            wsl_user_process = self.run_command(['wsl', '-d', 'Ubuntu', '-e', 'whoami'])
            wsl_user = wsl_user_process.stdout.strip()
            
            # Get absolute path of the local package
            windows_path = os.path.abspath(local_package)
            wsl_path = f"/home/{wsl_user}/kamiwaza-deploy-full.deb"
            
            # Copy the file to WSL
            self.run_command(['wsl', '-d', 'Ubuntu', '-e', 'cp', windows_path, wsl_path])
            
            # Run the installation commands in WSL
            self.update_status("Installing Kamiwaza in WSL...", 98)
            
            # Create a batch script to run the commands
            script = [
                "sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock",
                "sudo dpkg --unpack kamiwaza-deploy-full.deb",
                "sudo dpkg --configure -a"
            ]
            
            # Run the installation commands
            for cmd in script:
                result = self.run_command(['wsl', '-d', 'Ubuntu', '-e', 'bash', '-c', cmd])
                if result.returncode != 0:
                    raise Exception(f"WSL command failed: {cmd}\nError: {result.stderr}")
            
            # Don't remove the local file since we're using it as a local resource
            # os.remove("kamiwaza-deploy-full.deb")
            
            if user_wants_kamiwaza:
                self.update_status("Kamiwaza deployed in WSL successfully!", 100)
                messagebox.showinfo("Success", "Kamiwaza has been successfully deployed in WSL Ubuntu!")
            else:
                self.update_status("Installation completed without Kamiwaza deployment.", 100)
                messagebox.showinfo("Success", "Installation has been successfully completed without deploying Kamiwaza in WSL Ubuntu.")
            
        except Exception as e:
            messagebox.showerror("WSL Deployment Error", f"An error occurred during WSL deployment:\n{str(e)}")
            self.update_status("WSL deployment failed. Windows components installed successfully.", 100)

if __name__ == "__main__":
    if not is_admin():
        run_as_admin()
    else:
        app = KamiwazaInstaller()
        app.mainloop() 
