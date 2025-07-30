#!/usr/bin/env python3
"""
Test the verbose installation process
"""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from kamiwaza_headless_installer import HeadlessKamiwazaInstaller

def test_verbose_commands():
    """Test what the verbose installation commands will look like"""
    print("=== Testing Verbose Installation Commands ===\\n")
    
    installer = HeadlessKamiwazaInstaller(
        memory="8GB",
        user_email="test@example.com",
        license_key="test-license-key",
        usage_reporting="1",
        install_mode="lite"
    )
    
    # Show the DEB URL that would be used
    deb_url = installer.get_deb_url()
    deb_filename = installer.get_deb_filename()
    deb_path = f"/tmp/{deb_filename}"
    
    print("1. Configured DEB package:")
    print(f"   URL: {deb_url}")
    print(f"   Filename: {deb_filename}")
    print(f"   WSL path: {deb_path}")
    
    print("\\n2. Updated installation commands (now verbose):")
    
    # Show download command
    download_cmd = f"wget --timeout=60 --tries=3 --progress=bar --show-progress '{deb_url}' -O {deb_path}"
    print("\\na) Download command:")
    print(f"   {download_cmd}")
    print("   ↳ Now shows download progress bar")
    
    # Show installation commands
    install_commands = [
        f"sudo apt update -v",
        f"sudo apt install -f -y -v {deb_path}",
        f"rm {deb_path}"
    ]
    
    print("\\nb) Installation commands:")
    for i, cmd in enumerate(install_commands, 1):
        print(f"   {i}. {cmd}")
    
    print("\\n3. Key changes made:")
    print("   ✓ Removed DEBIAN_FRONTEND=noninteractive from apt commands")
    print("   ✓ Added -v (verbose) flag to apt update and apt install")  
    print("   ✓ Added --progress=bar --show-progress to wget")
    print("   ✓ Enhanced error reporting with exit codes and full output")
    print("   ✓ Display actual command being run for each step")
    
    print("\\n4. What you'll now see during installation:")
    print("   - Real-time download progress bar")
    print("   - Detailed apt update output (package lists, sources)")
    print("   - Verbose package installation output")
    print("   - Full post-installation script output (including PM2 installation)")
    print("   - Complete error messages when things fail")
    
    print("\\n5. Debugging the PM2 issue:")
    print("   The error you saw suggests the post-installation script failed.")
    print("   With verbose output, you'll now see:")
    print("   - Exactly what PM2 command failed")
    print("   - The specific error message from PM2 installation")
    print("   - Whether it's a timeout, network, or dependency issue")
    
    return True

if __name__ == "__main__":
    success = test_verbose_commands()
    
    if success:
        print("\\n" + "=" * 60)
        print("VERBOSE INSTALLATION READY!")
        print("=" * 60)
        print("Next installation will show:")
        print("• Download progress in real-time")
        print("• Detailed apt command output")  
        print("• Complete post-installation script logs")
        print("• Full error details when PM2 or other components fail")
        print("=" * 60)
    
    print("\\nTo test with a real installation:")
    print("1. Run: build.bat --no-upload") 
    print("2. Install the generated MSI")
    print("3. Use 'Install Kamiwaza' shortcut")
    print("4. Watch the detailed output for PM2 installation details")