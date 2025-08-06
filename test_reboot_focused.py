#!/usr/bin/env python3
"""
Focused test for WSL reboot functionality in the installer
"""
import sys
import os

# Add the current directory to Python path so we can import the installer class
sys.path.insert(0, os.path.dirname(__file__))

# Mock the log_output method to avoid stdout issues in test environment
class TestInstaller:
    def __init__(self):
        self.memory = "8GB"
        print("Test installer initialized")
    
    def log_output(self, message, progress=None):
        """Simple log output for testing"""
        print(f"LOG: {message}")
        if progress:
            print(f"PROGRESS: {progress}")
    
    def run_command(self, command, timeout=None):
        """Run command and return exit code, stdout, stderr"""
        import subprocess
        print(f"COMMAND: {' '.join(command)}")
        try:
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding='utf-8'
            )
            
            stdout, stderr = process.communicate(timeout=timeout)
            return process.returncode, stdout, stderr
            
        except subprocess.TimeoutExpired:
            process.kill()
            return 1, "", f"Command timed out after {timeout} seconds"
        except Exception as e:
            return 1, "", str(e)
    
    def create_dedicated_wsl_instance(self):
        """Test version of create_dedicated_wsl_instance with WSL reboot logic"""
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
        
        self.log_output(f"Found WSL instances: {wsl_instances}")
        
        if instance_name in wsl_instances:
            self.log_output(f"Existing {instance_name} WSL instance found")
            self.log_output("Restarting WSL to ensure clean state for installation...")
            
            # Stop the existing WSL instance
            self.log_output(f"Stopping {instance_name} WSL instance...")
            stop_ret, stop_out, stop_err = self.run_command(['wsl', '--terminate', instance_name], timeout=30)
            if stop_ret == 0:
                self.log_output(f"Successfully stopped {instance_name} instance")
            else:
                self.log_output(f"Warning: Could not stop {instance_name} instance: {stop_err}")
            
            # Shutdown all WSL instances to ensure clean restart
            self.log_output("Shutting down all WSL instances for clean restart...")
            shutdown_ret, shutdown_out, shutdown_err = self.run_command(['wsl', '--shutdown'], timeout=60)
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
            test_ret, test_out, test_err = self.run_command(['wsl', '-d', instance_name, 'echo', 'restart_test'], timeout=30)
            if test_ret == 0:
                self.log_output(f"Successfully restarted and verified {instance_name} instance")
                self.log_output(f"Test output: {test_out.strip()}")
            else:
                self.log_output(f"ERROR: Could not access {instance_name} instance after restart: {test_err}")
                self.log_output("This may indicate a corrupted WSL instance. Consider removing and recreating it.")
                return None
            
            return instance_name
        else:
            self.log_output(f"No existing {instance_name} instance found")
            return None

def main():
    print("=== FOCUSED WSL REBOOT TEST ===")
    
    # Create test installer instance
    installer = TestInstaller()
    
    # Test the WSL reboot functionality
    result = installer.create_dedicated_wsl_instance()
    
    if result:
        print(f"SUCCESS: WSL reboot test completed successfully, instance: {result}")
        return 0
    else:
        print("INFO: No existing kamiwaza instance found for testing, or reboot failed")
        return 1

if __name__ == "__main__":
    try:
        exit_code = main()
        print(f"\nTest completed with exit code: {exit_code}")
        sys.exit(exit_code)
    except Exception as e:
        print(f"CRITICAL ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)