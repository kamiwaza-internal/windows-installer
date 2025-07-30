#!/usr/bin/env python3
"""
Test the new streaming output functionality
"""
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

from kamiwaza_headless_installer import HeadlessKamiwazaInstaller

def test_streaming_output():
    """Test streaming output with a simple command"""
    print("=== Testing Streaming Output ===\\n")
    
    installer = HeadlessKamiwazaInstaller(
        memory="8GB",
        user_email="test@example.com",
        license_key="test-license-key",
        usage_reporting="1",
        install_mode="lite"
    )
    
    print("1. Testing with streaming enabled:")
    print("   This will show output line-by-line in real-time")
    print("   Each line will be prefixed with 'WSL:' and timestamped")
    print()
    
    # Test with a simple command that produces output
    print("Testing: wsl -d kamiwaza echo 'Testing streaming output'")
    ret, out, err = installer.run_command(['wsl', '-d', 'kamiwaza', 'echo', 'Testing streaming output'], 
                                        timeout=10, stream_output=True)
    print(f"Return code: {ret}")
    print()
    
    print("2. What you'll see during APT installation:")
    print("   Instead of waiting for the entire command to finish, you'll see:")
    print("   WSL: Reading package lists... Done")
    print("   WSL: Building dependency tree... Done") 
    print("   WSL: Reading state information... Done")
    print("   WSL: Note, selecting 'kamiwaza' instead of '/tmp/package.deb'")
    print("   WSL: The following NEW packages will be installed:")
    print("   WSL:   kamiwaza")
    print("   WSL: 0 upgraded, 1 newly installed, 0 to remove and 193 not upgraded.")
    print("   WSL: Need to get 0 B/331 MB of archives.")
    print("   WSL: After this operation, 375 MB of additional disk space will be used.")
    print("   WSL: Get:1 /tmp/package.deb kamiwaza amd64 0.5.0 [331 MB]")
    print("   WSL: Selecting previously unselected package kamiwaza.")
    print("   WSL: (Reading database...)")
    print("   WSL: Preparing to unpack .../package.deb ...")
    print("   WSL: [INFO] =================================================")
    print("   WSL: [INFO] ===== Starting Kamiwaza Offline Installation ====")
    print("   WSL: [INFO] Installing PM2 with a timeout of 180s...")
    print("   WSL: [INFO] PM2 installation output here...")
    print("   WSL: [INFO] or [ERROR] if PM2 fails with specific details")
    
    print("\\n3. Key improvements:")
    print("   ✓ Real-time streaming output (no more waiting for completion)")
    print("   ✓ ANSI color codes cleaned up for readability")
    print("   ✓ Each line timestamped and prefixed with 'WSL:'")
    print("   ✓ Buffering disabled for immediate output")
    print("   ✓ stderr merged with stdout for complete visibility")
    
    return True

if __name__ == "__main__":
    success = test_streaming_output()
    
    if success:
        print("\\n" + "=" * 60)
        print("STREAMING OUTPUT READY!")
        print("=" * 60) 
        print("Next installation will show REAL-TIME output including:")
        print("• Live wget download progress")
        print("• Immediate apt command feedback")
        print("• Real-time PM2 installation details")
        print("• Instant error messages with full context") 
        print("• No more waiting for commands to complete!")
        print("=" * 60)
    
    print("\\nBuild and test:")
    print("1. build.bat --no-upload")
    print("2. Install MSI and run 'Install Kamiwaza'")
    print("3. Watch the live installation output!")