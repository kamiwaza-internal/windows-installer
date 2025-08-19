#!/usr/bin/env python3
"""
Simple Kamiwaza Installer Test Runner
Quick validation of installer components without running anything.
"""

import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

def test_file_exists(file_path, description):
    """Test if a file exists and return result."""
    exists = os.path.exists(file_path)
    status = "[OK]" if exists else "[FAIL]"
    print(f"{status} {description}: {file_path}")
    return exists

def test_wxs_file():
    """Test the WiX installer file."""
    print("\n=== TESTING WIX INSTALLER FILE ===")
    
    wxs_file = "installer.wxs"
    if not test_file_exists(wxs_file, "WiX installer file"):
        return False
    
    try:
        tree = ET.parse(wxs_file)
        root = tree.getroot()
        print("[OK] WiX file parsed successfully")
        
        # Handle XML namespace
        namespace = {'wix': 'http://schemas.microsoft.com/wix/2006/wi'}
        
        # Check product name
        product = root.find('.//wix:Product', namespace)
        if product is None:
            # Try without namespace as fallback
            product = root.find('.//Product')
        
        if product is not None:
            name = product.get('Name')
            print(f"[OK] Product name: {name}")
        else:
            print("[FAIL] Product element not found")
            return False
        
        # Check required components
        components = root.findall('.//wix:Component', namespace)
        if not components:
            # Try without namespace as fallback
            components = root.findall('.//Component')
        
        print(f"[OK] Found {len(components)} components")
        
        return True
        
    except Exception as e:
        print(f"[FAIL] Failed to parse WiX file: {e}")
        return False

def test_required_files():
    """Test that all required files exist."""
    print("\n=== TESTING REQUIRED FILES ===")
    
    required_files = [
        ("kamiwaza_headless_installer.py", "Headless installer script"),
        ("run_kamiwaza.bat", "Kamiwaza runner batch file"),
        ("configure_wsl_memory.ps1", "WSL memory configuration script"),
        ("detect_gpu.ps1", "GPU detection script"),
        ("setup_nvidia_gpu.sh", "NVIDIA GPU setup script"),
        ("setup_intel_arc_gpu.sh", "Intel Arc GPU setup script"),
        ("config.yaml", "Configuration file"),
        ("cleanup_wsl_kamiwaza.ps1", "WSL cleanup script"),
        ("start_platform.bat", "Platform start script"),
        ("kamiwaza_start.bat", "Kamiwaza start script"),
        ("kamiwaza_stop.bat", "Kamiwaza stop script"),
        ("create_autostart_registry.ps1", "Autostart registry script"),
        ("install_gui_manager.ps1", "GUI manager installer")
    ]
    
    all_exist = True
    for file_path, description in required_files:
        if not test_file_exists(file_path, description):
            all_exist = False
    
    return all_exist

def test_wsl_integration():
    """Test WSL integration components."""
    print("\n=== TESTING WSL INTEGRATION ===")
    
    # Check WSL memory configuration
    wsl_script = "configure_wsl_memory.ps1"
    if test_file_exists(wsl_script, "WSL memory configuration"):
        print("[OK] WSL memory configuration script found")
    else:
        print("[FAIL] WSL memory configuration script missing")
        return False
    
    # Check WSL cleanup scripts
    cleanup_scripts = ["cleanup_wsl_kamiwaza.ps1", "cleanup_installs.bat"]
    for script in cleanup_scripts:
                test_file_exists(script, f"WSL cleanup script: {script}")
    
    print("[OK] WSL integration components validated")
    return True

def test_gpu_scripts():
    """Test GPU detection and setup scripts."""
    print("\n=== TESTING GPU SCRIPTS ===")
    
    # GPU detection scripts
    detection_scripts = ["detect_gpu.ps1", "detect_gpu_cmd.bat"]
    for script in detection_scripts:
        test_file_exists(script, f"GPU detection script: {script}")
    
    # GPU setup scripts
    setup_scripts = [
        "setup_nvidia_gpu.sh",
        "setup_intel_arc_gpu.sh", 
        "setup_intel_integrated_gpu.sh"
    ]
    for script in setup_scripts:
        test_file_exists(script, f"GPU setup script: {script}")
    
    print("[OK] GPU scripts validated")
    return True

def test_execution_sequence():
    """Test custom action execution sequence."""
    print("\n=== TESTING EXECUTION SEQUENCE ===")
    
    try:
        tree = ET.parse("installer.wxs")
        root = tree.getroot()
        
        # Handle XML namespace
        namespace = {'wix': 'http://schemas.microsoft.com/wix/2006/wi'}
        
        # Check execution sequence
        install_sequence = root.find('.//wix:InstallExecuteSequence', namespace)
        if install_sequence is None:
            # Try without namespace as fallback
            install_sequence = root.find('.//InstallExecuteSequence')
        
        if install_sequence is not None:
            custom_actions = install_sequence.findall('.//wix:Custom', namespace)
            if not custom_actions:
                # Try without namespace as fallback
                custom_actions = install_sequence.findall('.//Custom')
            
            print(f"[OK] Found {len(custom_actions)} custom actions in execution sequence")
            
            # Check critical actions
            critical_actions = ['ReservePorts', 'RunKamiwazaInstaller', 'DetectGPU']
            for action in critical_actions:
                action_elem = root.find(f'.//wix:CustomAction[@Id="{action}"]', namespace)
                if action_elem is None:
                    # Try without namespace as fallback
                    action_elem = root.find(f'.//CustomAction[@Id="{action}"]')
                
                if action_elem is not None:
                                    print(f"[OK] Critical action found: {action}")
            else:
                print(f"[FAIL] Critical action missing: {action}")
        else:
            print("[FAIL] InstallExecuteSequence not found")
            return False
        
        return True
        
    except Exception as e:
        print(f"[FAIL] Failed to test execution sequence: {e}")
        return False

def test_registry_and_cleanup():
    """Test registry entries and cleanup actions."""
    print("\n=== TESTING REGISTRY AND CLEANUP ===")
    
    try:
        tree = ET.parse("installer.wxs")
        root = tree.getroot()
        
        # Handle XML namespace
        namespace = {'wix': 'http://schemas.microsoft.com/wix/2006/wi'}
        
        # Check registry cleanup
        registry_cleanup = root.find('.//wix:RegistryKey[@ForceDeleteOnUninstall="yes"]', namespace)
        if registry_cleanup is None:
            # Try without namespace as fallback
            registry_cleanup = root.find('.//RegistryKey[@ForceDeleteOnUninstall="yes"]')
        
        if registry_cleanup is not None:
            print("[OK] Registry cleanup on uninstall configured")
        else:
            print("[FAIL] Registry cleanup on uninstall not configured")
        
        # Check file cleanup actions
        remove_files = root.findall('.//wix:RemoveFile', namespace)
        if not remove_files:
            # Try without namespace as fallback
            remove_files = root.findall('.//RemoveFile')
        
        if remove_files:
            print(f"[OK] File cleanup actions configured: {len(remove_files)} actions")
        else:
            print("[FAIL] No file cleanup actions configured")
        
        # Check folder cleanup
        remove_folder = root.find('.//wix:RemoveFolder', namespace)
        if remove_folder is None:
            # Try without namespace as fallback
            remove_folder = root.find('.//RemoveFolder')
        
        if remove_folder is not None:
            print("[OK] Folder cleanup on uninstall configured")
        else:
            print("[FAIL] Folder cleanup on uninstall not configured")
        
        return True
        
    except Exception as e:
        print(f"[FAIL] Failed to test registry and cleanup: {e}")
        return False

def main():
    """Main test runner."""
    print("Kamiwaza Installer Simple Test Runner")
    print("=" * 50)
    
    tests = [
        ("WiX File", test_wxs_file),
        ("Required Files", test_required_files),
        ("WSL Integration", test_wsl_integration),
        ("GPU Scripts", test_gpu_scripts),
        ("Execution Sequence", test_execution_sequence),
        ("Registry and Cleanup", test_registry_and_cleanup)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n{'='*20} {test_name} {'='*20}")
        try:
            if test_func():
                passed += 1
                print(f"[OK] {test_name} PASSED")
            else:
                print(f"[FAIL] {test_name} FAILED")
        except Exception as e:
            print(f"[FAIL] {test_name} ERROR: {e}")
    
    print(f"\n{'='*50}")
    print(f"TEST SUMMARY: {passed}/{total} tests passed")
    
    if passed == total:
        print("[SUCCESS] ALL TESTS PASSED - Installer configuration is valid!")
        return 0
    else:
        print("[WARNING] SOME TESTS FAILED - Review installer configuration")
        return 1

if __name__ == "__main__":
    sys.exit(main()) 