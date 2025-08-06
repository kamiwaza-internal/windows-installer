#!/usr/bin/env python3
"""
Simple script to create a testable version of the Kamiwaza installer
by replacing the DEB_FILE_URL placeholder with a test URL
"""

import os
import shutil

def create_test_installer():
    """Create a testable version of the installer"""
    
    # Read the config to get the DEB_FILE_URL
    deb_url = None
    try:
        with open('config.yaml', 'r') as f:
            for line in f:
                if line.strip().startswith('deb_file_url:'):
                    deb_url = line.split(':', 1)[1].strip()
                    break
    except FileNotFoundError:
        print("config.yaml not found, using test URL")
        deb_url = "https://example.com/test-package.deb"
    
    if not deb_url:
        print("No DEB_FILE_URL found in config.yaml, using test URL")
        deb_url = "https://example.com/test-package.deb"
    
    print(f"Using DEB URL: {deb_url}")
    
    # Read the template file
    template_file = 'kamiwaza_headless_installer.py'
    output_file = 'kamiwaza_headless_installer_test.py'
    
    try:
        with open(template_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Replace the placeholder
        content = content.replace('{{DEB_FILE_URL}}', deb_url)
        
        # Write the testable version
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"Created testable installer: {output_file}")
        print(f"DEB_FILE_URL placeholder replaced with: {deb_url}")
        
        return output_file
        
    except FileNotFoundError:
        print(f"Template file not found: {template_file}")
        return None
    except Exception as e:
        print(f"Error creating test installer: {e}")
        return None

if __name__ == "__main__":
    test_file = create_test_installer()
    if test_file:
        print(f"\nYou can now test the installer with:")
        print(f"python {test_file} --help")
        print(f"python {test_file} --memory 8GB --email test@example.com") 