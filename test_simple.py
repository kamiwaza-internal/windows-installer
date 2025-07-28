#!/usr/bin/env python3
"""
Simple test script for MSI CustomAction validation  
"""
import sys
import os
from datetime import datetime

def main():
    print(f"[{datetime.now()}] Test script started successfully!")
    print(f"Python version: {sys.version}")
    print(f"Working directory: {os.getcwd()}")
    print(f"Arguments: {sys.argv}")
    
    # Test basic functionality
    try:
        import yaml
        print("[OK] PyYAML import successful")
    except ImportError as e:
        print(f"[ERROR] PyYAML import failed: {e}")
        return 1
        
    try:
        import requests
        print("[OK] Requests import successful")  
    except ImportError as e:
        print(f"[ERROR] Requests import failed: {e}")
        return 1
    
    print("[OK] All tests passed - CustomAction will work!")
    return 0

if __name__ == "__main__":
    sys.exit(main())