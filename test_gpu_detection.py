#!/usr/bin/env python3
"""
Quick test script for GPU detection
Run this to see if GPU detection is working properly
"""

import os
import sys

def test_gpu_detection():
    """Test the GPU detection logic"""
    print("=== TESTING GPU DETECTION ===")
    
    # Check what GPU setup scripts exist
    nvidia_script = "setup_nvidia_gpu.sh"
    intel_arc_script = "setup_intel_arc_gpu.sh"
    intel_integrated_script = "setup_intel_integrated_gpu.sh"
    
    print(f"Checking for GPU setup scripts...")
    print(f"  NVIDIA script: {nvidia_script} - {'EXISTS' if os.path.exists(nvidia_script) else 'NOT FOUND'}")
    print(f"  Intel Arc script: {intel_arc_script} - {'EXISTS' if os.path.exists(intel_arc_script) else 'NOT FOUND'}")
    print(f"  Intel Integrated script: {intel_integrated_script} - {'EXISTS' if os.path.exists(intel_integrated_script) else 'NOT FOUND'}")
    
    # Determine GPU type
    if os.path.exists(nvidia_script):
        print("\n✅ NVIDIA RTX GPU detected!")
        print("   GPU acceleration: NVIDIA_RTX")
        print("   Restart required: YES")
        
    elif os.path.exists(intel_arc_script):
        print("\n✅ Intel Arc GPU detected!")
        print("   GPU acceleration: INTEL_ARC")
        print("   Restart required: YES")
        
    elif os.path.exists(intel_integrated_script):
        print("\n✅ Intel Integrated GPU detected!")
        print("   GPU acceleration: INTEL_INTEGRATED")
        print("   Restart required: YES")
        
    else:
        print("\n❌ No GPU setup scripts found")
        print("   GPU acceleration: CPU_ONLY")
        print("   Restart required: NO")
        print("\n   This means either:")
        print("   1. PowerShell detection didn't run")
        print("   2. No supported GPUs detected")
        print("   3. Scripts weren't created")
    
    print("\n=== TEST COMPLETE ===")

if __name__ == "__main__":
    test_gpu_detection() 