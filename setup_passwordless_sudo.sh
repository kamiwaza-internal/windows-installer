#!/bin/bash

# One-time setup script to enable passwordless sudo for kamiwaza user
# Run this once with: sudo ./setup_passwordless_sudo.sh

set -e

echo "Setting up passwordless sudo for kamiwaza user..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (with sudo)"
    echo "Usage: sudo ./setup_passwordless_sudo.sh"
    exit 1
fi

# Create sudoers file for kamiwaza user
SUDOERS_FILE="/etc/sudoers.d/kamiwaza-admin"

echo "Creating sudoers configuration: $SUDOERS_FILE"

cat > "$SUDOERS_FILE" << 'EOF'
# Allow kamiwaza user to run common administrative commands without password
# This is for the Kamiwaza Windows installer integration

kamiwaza ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /usr/bin/dpkg, /usr/bin/debconf-set-selections, /usr/bin/dpkg-reconfigure, /usr/bin/debconf-show, /usr/bin/systemctl, /usr/bin/service
EOF

# Set proper permissions
chmod 440 "$SUDOERS_FILE"

# Validate the sudoers file
if visudo -c -f "$SUDOERS_FILE"; then
    echo "[OK] Sudoers configuration created successfully!"
    echo "The kamiwaza user can now run administrative commands without password prompts."
    echo ""
    echo "Commands enabled:"
    echo "  - apt-get (package management)"
    echo "  - dpkg (package installation)" 
    echo "  - debconf-* (configuration)"
    echo "  - systemctl/service (service management)"
    echo ""
    echo "Test with: sudo -u kamiwaza sudo -n apt-get --version"
else
    echo "[ERROR] Error: Invalid sudoers configuration!"
    rm -f "$SUDOERS_FILE"
    exit 1
fi 