#!/usr/bin/env python3
"""
Create a mock test version of the installer that creates fake DEB files
for testing the installation process without downloading real packages
"""

import os
import shutil

def create_mock_test_installer():
    """Create a mock test version of the installer"""
    
    template_file = 'kamiwaza_headless_installer.py'
    output_file = 'kamiwaza_headless_installer_mock.py'
    
    try:
        with open(template_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Replace the DEB URL with a mock placeholder
        content = content.replace('{{DEB_FILE_URL}}', 'MOCK_DEB_PLACEHOLDER')
        
        # Insert mock DEB creation logic
        mock_deb_method = '''
    def create_mock_deb_file(self, wsl_cmd, deb_path):
        """Create a mock DEB file for testing purposes"""
        self.log_output("=== MOCK TEST MODE: Creating fake DEB file ===")
        
        # Create a simple text file that looks like a DEB
        mock_deb_content = f"""Package: kamiwaza-test
Version: 0.5.0-test
Architecture: amd64
Maintainer: Kamiwaza Test <test@kamiwaza.ai>
Description: Mock Kamiwaza package for testing
 This is a fake DEB file created for testing the installer.
 It will not actually install Kamiwaza.
"""
        
        # Write the mock DEB content to WSL
        create_cmd = f"echo '{mock_deb_content}' > {deb_path}.txt && mv {deb_path}.txt {deb_path}"
        ret, out, err = self.run_command(wsl_cmd + ['bash', '-c', create_cmd], timeout=30)
        
        if ret == 0:
            self.log_output(f"SUCCESS: Mock DEB file created at {deb_path}")
            self.log_output("NOTE: This is a FAKE DEB file for testing only!")
            return True
        else:
            self.log_output(f"ERROR: Failed to create mock DEB: {err}")
            return False
'''
        
        # Insert the mock method before the get_deb_url method
        content = content.replace('    def get_deb_url(self):', mock_deb_method + '\n    def get_deb_url(self):')
        
        # Modify the get_deb_url method to return the mock URL
        content = content.replace(
            'def get_deb_url(self):\n        """Get DEB URL - will be replaced during build"""\n        return "MOCK_DEB_PLACEHOLDER"',
            '''def get_deb_url(self):
        """Get DEB URL - will be replaced during build"""
        return "MOCK_DEB_PLACEHOLDER"'''
        )
        
        # Modify the download section to create mock DEB instead
        download_section_old = '''            download_cmd = f"wget --timeout=60 --tries=3 --progress=bar --show-progress '{deb_url}' -O {deb_path}"
            self.log_output(f"Download command: {download_cmd}")
            
            ret, download_out, err = self.run_command(wsl_cmd + ['bash', '-c', download_cmd], timeout=300)
            if ret != 0:
                self.log_output(f"CRITICAL ERROR: Download failed with exit code {ret}")
                self.log_output(f"Download error: {err}")
                self.log_output(f"Download output: {download_out}")'''
        
        download_section_new = '''            # MOCK TEST MODE: Create fake DEB instead of downloading
            if deb_url == "MOCK_DEB_PLACEHOLDER":
                self.log_output("MOCK TEST MODE: Creating fake DEB file instead of downloading")
                ret = 0 if self.create_mock_deb_file(wsl_cmd, deb_path) else 1
                download_out = "Mock DEB created successfully"
                err = ""
            else:
                download_cmd = f"wget --timeout=60 --tries=3 --progress=bar --show-progress '{deb_url}' -O {deb_path}"
                self.log_output(f"Download command: {download_cmd}")
                
                ret, download_out, err = self.run_command(wsl_cmd + ['bash', '-c', download_cmd], timeout=300)
            
            if ret != 0:
                self.log_output(f"CRITICAL ERROR: Download/Mock creation failed with exit code {ret}")
                self.log_output(f"Error: {err}")
                self.log_output(f"Output: {download_out}")'''
        
        content = content.replace(download_section_old, download_section_new)
        
        # Modify the install section to handle mock DEBs
        install_section_old = '''            install_cmd = f"""
            echo '[{timestamp}] Starting apt install of {deb_path}' > /tmp/kamiwaza_install.log
            export DEBIAN_FRONTEND=noninteractive
            sudo -E apt install -f -y {deb_path} 2>&1 | tee -a /tmp/kamiwaza_install.log'''
        
        install_section_new = '''            # Check if this is a mock DEB
            if deb_url == "MOCK_DEB_PLACEHOLDER":
                self.log_output("MOCK TEST MODE: Simulating package installation")
                install_cmd = f"""
            echo '[{timestamp}] MOCK: Starting simulated install of {deb_path}' > /tmp/kamiwaza_install.log
            echo 'MOCK TEST MODE: This is a simulated installation' | tee -a /tmp/kamiwaza_install.log
            echo 'Reading package lists...' | tee -a /tmp/kamiwaza_install.log
            sleep 2
            echo 'Building dependency tree...' | tee -a /tmp/kamiwaza_install.log
            sleep 1
            echo 'Reading state information...' | tee -a /tmp/kamiwaza_install.log
            sleep 1
            echo 'The following NEW packages will be installed:' | tee -a /tmp/kamiwaza_install.log
            echo '  kamiwaza-test' | tee -a /tmp/kamiwaza_install.log
            sleep 1
            echo 'Setting up kamiwaza-test (0.5.0-test) ...' | tee -a /tmp/kamiwaza_install.log
            echo 'MOCK: kamiwaza command installed at /usr/local/bin/kamiwaza' | tee -a /tmp/kamiwaza_install.log
            
            # Create a mock kamiwaza command
            sudo mkdir -p /usr/local/bin
            echo '#!/bin/bash' | sudo tee /usr/local/bin/kamiwaza
            echo 'echo "MOCK KAMIWAZA COMMAND"' | sudo tee -a /usr/local/bin/kamiwaza
            echo 'echo "This is a test installation - not real Kamiwaza"' | sudo tee -a /usr/local/bin/kamiwaza
            echo 'echo "Arguments: $@"' | sudo tee -a /usr/local/bin/kamiwaza
            sudo chmod +x /usr/local/bin/kamiwaza
            
            echo 'Processing triggers for man-db...' | tee -a /tmp/kamiwaza_install.log
            echo 'MOCK INSTALLATION COMPLETED SUCCESSFULLY' | tee -a /tmp/kamiwaza_install.log
            INSTALL_EXIT_CODE=0
            echo "[{timestamp}] Mock install completed with exit code $INSTALL_EXIT_CODE" >> /tmp/kamiwaza_install.log
            
            exit $INSTALL_EXIT_CODE"""
            else:
                install_cmd = f"""
            echo '[{timestamp}] Starting apt install of {deb_path}' > /tmp/kamiwaza_install.log
            export DEBIAN_FRONTEND=noninteractive
            sudo -E apt install -f -y {deb_path} 2>&1 | tee -a /tmp/kamiwaza_install.log'''
        
        content = content.replace(install_section_old, install_section_new)
        
        # Write the mock test version
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"Created mock test installer: {output_file}")
        
        # Copy it to the build version location
        shutil.copy2(output_file, 'kamiwaza_headless_installer_build.py')
        print("Copied mock installer to build location")
        
        return output_file
        
    except FileNotFoundError:
        print(f"Template file not found: {template_file}")
        return None
    except Exception as e:
        print(f"Error creating mock test installer: {e}")
        return None

if __name__ == "__main__":
    mock_file = create_mock_test_installer()
    if mock_file:
        print(f"\nMock test installer created: {mock_file}")
        print("This installer will create fake DEB files and simulate installation")
        print("Use this for testing the installer flow without real packages")