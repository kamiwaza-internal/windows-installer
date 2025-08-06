#!/bin/bash
# NVIDIA GPU Setup Script for WSL2 (Placeholder)
# This file will be replaced by the actual GPU detection script during installation

echo "Setting up NVIDIA GPU support..."

# Check if nvidia-smi is available
if which nvidia-smi > /dev/null 2>&1; then
    echo "NVIDIA drivers detected in WSL"
    nvidia-smi
else
    echo "NVIDIA drivers not detected. Please ensure:"
    echo "1. You have installed NVIDIA GPU drivers on Windows"
    echo "2. You are using WSL2 not WSL1"
    echo "3. Your Windows version supports GPU passthrough"
fi

# Set environment variables for CUDA
echo 'export CUDA_HOME=/usr/local/cuda' >> ~/.bashrc
echo "export PATH=\$PATH:\$CUDA_HOME/bin" >> ~/.bashrc
echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$CUDA_HOME/lib64" >> ~/.bashrc

echo "NVIDIA GPU setup completed!" 