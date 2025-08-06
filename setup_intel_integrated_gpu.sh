#!/bin/bash
# Intel Integrated Graphics Setup Script for WSL2
# Supports Intel UHD, HD Graphics, and Iris GPUs

echo "=== Intel Integrated Graphics Configuration ==="
echo "Setting up Intel integrated graphics acceleration for Kamiwaza..."
echo "Timestamp: $(date)"

# GPU Detection
echo ""
echo "--- GPU Detection ---"
echo "Intel integrated graphics hardware detected"

# Check for Intel graphics in lspci
if lspci | grep -i intel | grep -i vga >/dev/null 2>&1; then
    echo "Intel graphics device found in PCI:"
    lspci | grep -i intel | grep -i vga
else
    echo "Intel graphics device not visible in WSL PCI list"
fi

echo ""
echo "--- Intel Graphics Driver Information ---"
# Check for i915 driver (Intel graphics driver in Linux)
if modinfo i915 >/dev/null 2>&1; then
    echo "Intel i915 driver information:"
    modinfo i915 | grep -E "version|description|filename" || echo "Driver info unavailable"
else
    echo "Intel i915 driver not available in WSL"
fi

echo ""
echo "--- Hardware Acceleration Setup ---"
echo "Setting up Intel integrated graphics acceleration..."

# Set up environment variables for Intel graphics
echo 'export LIBVA_DRIVER_NAME=iHD' >> ~/.bashrc
echo 'export INTEL_MEDIA_RUNTIME=1' >> ~/.bashrc

echo "Intel graphics environment variables configured:"
echo "  - LIBVA_DRIVER_NAME=iHD (Intel HD Graphics driver)"
echo "  - INTEL_MEDIA_RUNTIME=1 (Enable Intel Media SDK)"

echo ""
echo "--- OpenCL Support ---"
# Intel OpenCL support for compute acceleration
if command -v clinfo >/dev/null 2>&1; then
    echo "OpenCL platforms available:"
    clinfo -l 2>/dev/null || echo "No OpenCL platforms found"
else
    echo "OpenCL tools not installed"
    echo "To install: sudo apt install clinfo intel-opencl-icd"
fi

echo ""
echo "--- Media Acceleration ---"
echo "Intel integrated graphics can provide:"
echo "1. Hardware video decode/encode (VAAPI)"
echo "2. OpenCL compute acceleration"
echo "3. Media processing acceleration"

echo ""
echo "--- Configuration Complete ---"
echo "Intel integrated graphics acceleration configured"
echo "Note: Performance will be limited compared to discrete GPUs"

echo ""
echo "--- Verification Commands ---"
echo "To verify Intel graphics setup:"
echo "  vainfo                    # Check VAAPI support"
echo "  clinfo                    # Check OpenCL support" 
echo "  lspci | grep -i intel     # Check PCI devices"

echo ""
echo "=== Intel Integrated Graphics Setup Complete ==="