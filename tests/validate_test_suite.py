#!/usr/bin/env python3
"""
Test Suite Validator for Kamiwaza Installer
Validates that the test suite is healthy and ready to run.
"""

import os
import sys
from pathlib import Path

def check_test_files():
    """Check that required test files exist."""
    print("Checking test files...")
    
    required_files = [
        "tests/test_installer.py",
        "tests/requirements.txt"
    ]
    
    missing_files = []
    for file_path in required_files:
        if not os.path.exists(file_path):
            missing_files.append(file_path)
            print(f"[MISSING] {file_path}")
        else:
            print(f"[OK] {file_path}")
    
    return len(missing_files) == 0

def check_python_version():
    """Check Python version compatibility."""
    print("Checking Python version...")
    
    version = sys.version_info
    if version.major >= 3 and version.minor >= 8:
        print(f"[OK] Python {version.major}.{version.minor}.{version.micro}")
        return True
    else:
        print(f"[FAIL] Python {version.major}.{version.minor}.{version.micro} - requires Python 3.8+")
        return False

def check_dependencies():
    """Check if required dependencies are available."""
    print("Checking test dependencies...")
    
    required_modules = ['pytest']
    missing_modules = []
    
    for module in required_modules:
        try:
            __import__(module)
            print(f"[OK] {module}")
        except ImportError:
            missing_modules.append(module)
            print(f"[MISSING] {module}")
    
    if missing_modules:
        print(f"Install missing dependencies with: pip install {' '.join(missing_modules)}")
        return False
    
    return True

def check_installer_files():
    """Check that core installer files exist."""
    print("Checking installer files...")
    
    core_files = [
        "installer.wxs",
        "kamiwaza_headless_installer.py",
        "run_kamiwaza.bat",
        "detect_gpu.ps1"
    ]
    
    missing_files = []
    for file_path in core_files:
        if not os.path.exists(file_path):
            missing_files.append(file_path)
            print(f"[MISSING] {file_path}")
        else:
            print(f"[OK] {file_path}")
    
    return len(missing_files) == 0

def main():
    """Main validation function."""
    print("=" * 50)
    print("KAMIWAZA INSTALLER TEST SUITE VALIDATOR")
    print("=" * 50)
    
    checks = [
        ("Python Version", check_python_version),
        ("Test Files", check_test_files),
        ("Dependencies", check_dependencies),
        ("Installer Files", check_installer_files)
    ]
    
    passed = 0
    total = len(checks)
    
    for check_name, check_func in checks:
        print(f"\n--- {check_name} ---")
        try:
            if check_func():
                passed += 1
                print(f"✓ {check_name} PASSED")
            else:
                print(f"✗ {check_name} FAILED")
        except Exception as e:
            print(f"✗ {check_name} ERROR: {e}")
    
    print(f"\n{'=' * 50}")
    print(f"VALIDATION SUMMARY: {passed}/{total} checks passed")
    
    if passed == total:
        print("✓ Test suite is healthy and ready to run!")
        return 0
    else:
        print("✗ Test suite has issues that need to be resolved")
        return 1

if __name__ == "__main__":
    sys.exit(main())
