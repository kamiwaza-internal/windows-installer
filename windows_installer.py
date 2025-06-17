import tkinter as tk
from tkinter import ttk, messagebox
from threading import Thread
import subprocess

class KamiwazaInstaller(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Kamiwaza Installer")
        self.geometry("600x400")

        # Progress bar
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(self, variable=self.progress_var, maximum=100)
        self.progress_bar.pack(fill='x', padx=20, pady=10)

        # Log output
        self.log_text = tk.Text(self, wrap='word', height=12, font=('Courier', 10))
        self.log_text.pack(fill='both', expand=True, padx=20, pady=10)

        # Install button
        self.install_button = ttk.Button(self, text="Install in WSL", command=self.start_installation)
        self.install_button.pack(pady=10)

        # Close button (hidden by default)
        self.close_button = ttk.Button(self, text="Close", command=self.quit)
        self.close_button.pack(pady=10)
        self.close_button.pack_forget()

    def log_output(self, message):
        self.log_text.insert(tk.END, message + "\n")
        self.log_text.see(tk.END)
        self.update()

    def update_progress(self, value):
        self.progress_var.set(value)
        self.update()

    def run_command(self, command):
        self.log_output(f"Running: {' '.join(command)}")
        try:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            stdout, stderr = process.communicate()
            if stdout:
                self.log_output(stdout)
            if stderr:
                self.log_output(stderr)
            return process.returncode, stdout, stderr
        except Exception as e:
            self.log_output(f"Error running command: {e}")
            return 1, "", str(e)

    def start_installation(self):
        self.install_button.config(state='disabled')
        Thread(target=self.perform_installation).start()

    def perform_installation(self):
        try:
            # 1. Check for WSL
            self.log_output("Checking for WSL...")
            self.update_progress(10)
            ret, out, err = self.run_command(['wsl', '--status'])
            if ret != 0:
                self.log_output("WSL not found. Attempting to install WSL...")
                self.update_progress(20)
                ret, out, err = self.run_command(['wsl', '--install'])
                if ret != 0:
                    raise Exception("Failed to install WSL. Please install it manually and try again.")
                self.log_output("WSL installed. Please reboot if this is your first time installing WSL.")
            else:
                self.log_output("WSL is present.")

            # 2. Download the .deb in WSL
            self.log_output("Downloading .deb package in WSL...")
            self.update_progress(40)
            deb_url = "https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/kamiwaza_0.4.1-rc1_build01_amd64.deb"
            download_cmd = f"wget {deb_url} -P /tmp/"
            ret, out, err = self.run_command(['wsl', 'bash', '-c', download_cmd])
            if ret != 0:
                raise Exception("Failed to download .deb package in WSL.")

            self.log_output(".deb download complete.")

            # 3. Install the .deb in WSL
            self.log_output("Updating apt and installing .deb package in WSL...")
            self.update_progress(70)
            install_cmds = [
                "sudo apt update",
                "sudo apt install -f -y /tmp/kamiwaza_0.4.1-rc1_build01_amd64.deb",
                "rm /tmp/kamiwaza_0.4.1-rc1_build01_amd64.deb"
            ]
            for cmd in install_cmds:
                ret, out, err = self.run_command(['wsl', 'bash', '-c', cmd])
                if ret != 0:
                    raise Exception(f"WSL command failed: {cmd}\nError: {err}")

            self.log_output(".deb install complete.")

            self.log_output("""
Post-Installation Details:
- Kamiwaza is located at /opt/kamiwaza/kamiwaza
- A 'kamiwaza' user will be created if not present.

To start Kamiwaza:
    su kamiwaza
    kamiwaza start
""")

            self.update_progress(100)
            self.log_output("Installation finished successfully!")
            messagebox.showinfo("Success", "Kamiwaza has been successfully deployed in WSL Ubuntu!")
            self.close_button.pack()  # Show the close button

        except Exception as e:
            self.log_output(f"Error: {str(e)}")
            messagebox.showerror("Installation Error", f"An error occurred:\n{str(e)}")
            self.close_button.pack()
        finally:
            self.install_button.config(state='normal')

if __name__ == "__main__":
    app = KamiwazaInstaller()
    app.mainloop() 
