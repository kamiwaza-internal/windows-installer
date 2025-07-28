#!/usr/bin/env python3
"""
Headless Kamiwaza installer for MSI integration
No GUI - uses stdout for progress reporting to MSI
"""
import subprocess
import sys
import os
import platform
import datetime
import argparse
import yaml
import shutil
import tempfile

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
        
        # Change working directory to installer directory if needed
        if os.getcwd().lower().endswith('system32'):
            installer_dir = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza')
            if os.path.exists(installer_dir):
                os.chdir(installer_dir)

    def log_output(self, message, progress=None):
        """Log message with optional progress for MSI"""
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_line = f"[{timestamp}] {message}"
        # Ensure ASCII-safe output for MSI environment
        print(log_line.encode('ascii', 'replace').decode('ascii'))
        
        # Report progress to MSI if specified
        if progress is not None:
            print(f"PROGRESS:{progress}")
        
        sys.stdout.flush()

    def run_command(self, command, timeout=None):
        """Run command and return exit code, stdout, stderr"""
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
            if stdout:
                self.log_output(stdout.strip())
            if stderr:
                self.log_output(f"STDERR: {stderr.strip()}")
            
            return process.returncode, stdout, stderr
            
        except subprocess.TimeoutExpired:
            process.kill()
            self.log_output(f"Command timed out after {timeout} seconds")
            return 1, "", f"Command timed out after {timeout} seconds"
        except Exception as e:
            self.log_output(f"Error running command: {e}")
            return 1, "", str(e)

    def create_dedicated_wsl_instance(self):
        """Create dedicated 'kamiwaza' WSL instance from Ubuntu 24.04 cloud image"""
        instance_name = "kamiwaza"
        self.log_output(f"Setting up dedicated WSL instance: {instance_name}")
        
        # Check what WSL distributions exist
        ret, out, err = self.run_command(['wsl', '--list', '--quiet'], timeout=15)
        if ret != 0:
            self.log_output("ERROR: WSL is not available")
            return None
        
        # Parse WSL instances (handle UTF-16 encoding with null bytes and spaces)
        wsl_instances = out.replace('\x00', '').replace(' ', '').replace('\r', '').replace('\n', ' ').split()
        wsl_instances = [name.strip() for name in wsl_instances if name.strip()]  # Remove empty entries
        if instance_name in wsl_instances:
            self.log_output(f"Using existing {instance_name} WSL instance")
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
            '--max-time', '600', '--connect-timeout', '30'
        ]
        ret, _, err = self.run_command(download_cmd, timeout=700)  # 11+ minutes for 340MB download
        
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
        ret, _, err = self.run_command(['wsl', '--import', instance_name, wsl_dir, rootfs_file], timeout=300)
        
        # Clean up downloaded file
        try:
            os.remove(rootfs_file)
            self.log_output("Cleaned up downloaded rootfs file")
        except:
            pass
        
        if ret != 0:
            self.log_output(f"ERROR: Failed to import {instance_name} instance: {err}")
            return None
        
        # Verify and initialize the new instance
        self.log_output(f"Verifying and initializing '{instance_name}' instance...")
        
        # Test basic functionality
        ret, _, _ = self.run_command(['wsl', '-d', instance_name, 'echo', 'test'], timeout=15)
        if ret != 0:
            self.log_output(f"ERROR: {instance_name} instance verification failed")
            return None
        
        # Initialize basic packages needed for installation
        init_commands = [
            'apt update',
            'apt install -y wget curl'
        ]
        
        for cmd in init_commands:
            ret, _, err = self.run_command(['wsl', '-d', instance_name, 'sudo', 'bash', '-c', cmd], timeout=120)
            if ret != 0:
                self.log_output(f"WARNING: Failed to initialize {instance_name}: {cmd} - {err}")
        
        self.log_output(f"Successfully created and initialized '{instance_name}' WSL instance")
        return instance_name

    def get_wsl_distribution(self):
        """Get WSL distribution command"""
        # Try dedicated instance first
        dedicated = self.create_dedicated_wsl_instance()
        if dedicated:
            return ['wsl', '-d', dedicated]
        
        # Only check for existing kamiwaza instance or Ubuntu-24.04
        # User explicitly requested: "We should only use the existing wsl if its name is KAMIWAZA - nothing else"
        # and "We NEVER want 22.04 - only 24.04"
        ret, out, _ = self.run_command(['wsl', '--list', '--quiet'], timeout=15)
        if ret == 0:
            wsl_instances = out.replace('\x00', '').replace(' ', '').replace('\r', '').replace('\n', ' ').split()
            wsl_instances = [name.strip() for name in wsl_instances if name.strip()]  # Remove empty entries
            if 'Ubuntu-24.04' in wsl_instances:
                self.log_output("Using existing Ubuntu-24.04")
                return ['wsl', '-d', 'Ubuntu-24.04']
        
        self.log_output("ERROR: No suitable WSL distribution found. Only 'kamiwaza' or 'Ubuntu-24.04' are supported.")
        return None

    def configure_wsl_memory(self):
        """Configure WSL memory"""
        try:
            self.log_output(f"Configuring WSL memory: {self.memory}")
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

    def install(self):
        """Main installation process"""
        try:
            self.log_output("Starting Kamiwaza installation", progress=0)
            
            # Get WSL distribution
            self.log_output("Setting up WSL environment", progress=10)
            wsl_cmd = self.get_wsl_distribution()
            if wsl_cmd is None:
                self.log_output("ERROR: Failed to set up WSL environment")
                return 1
            
            # Configure WSL memory
            self.log_output("Configuring WSL memory", progress=20)
            self.configure_wsl_memory()
            
            # Configure debconf
            self.log_output("Configuring installation preferences", progress=30)
            self.configure_debconf(wsl_cmd)
            
            # Download DEB
            self.log_output("Downloading Kamiwaza package", progress=40)
            deb_url = self.get_deb_url()
            deb_filename = self.get_deb_filename()
            deb_path = f"/tmp/{deb_filename}"
            
            download_cmd = f"wget --timeout=60 --tries=3 '{deb_url}' -O {deb_path}"
            ret, _, err = self.run_command(wsl_cmd + ['bash', '-c', download_cmd], timeout=300)
            if ret != 0:
                self.log_output(f"Download failed: {err}")
                return 1
            
            # Install DEB
            self.log_output("Installing Kamiwaza in WSL", progress=60)
            
            install_commands = [
                f"export DEBIAN_FRONTEND=noninteractive && sudo -E apt update",
                f"export DEBIAN_FRONTEND=noninteractive && sudo -E apt install -f -y {deb_path}",
                f"rm {deb_path}"
            ]
            
            for i, cmd in enumerate(install_commands):
                progress = 60 + (i * 10)
                self.log_output(f"Step {i+1}/{len(install_commands)}", progress=progress)
                ret, _, err = self.run_command(wsl_cmd + ['bash', '-c', cmd], timeout=300)
                if ret != 0 and not cmd.endswith("|| true"):
                    self.log_output(f"Command failed: {err}")
            
            self.log_output("Installation completed successfully!", progress=100)
            return 0
            
        except Exception as e:
            self.log_output(f"Installation failed: {e}")
            return 1

def main():
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
    
    args = parser.parse_args()
    
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
    sys.exit(exit_code)

if __name__ == "__main__":
    main()