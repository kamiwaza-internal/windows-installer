#!/bin/bash

# Setup debconf values for Kamiwaza installation
# This script configures debconf with user preferences from the Windows MSI installer

set -e

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to safely set debconf value
set_debconf() {
    local package="$1"
    local question="$2"
    local type="$3"
    local value="$4"
    
    log_message "Setting debconf: $package/$question = $value"
    
    # Pre-seed the debconf database
    echo "$package $question $type $value" | debconf-set-selections
    
    # Verify the setting was applied
    if debconf-get-selections | grep -q "$package/$question"; then
        log_message "Successfully set $package/$question"
    else
        log_message "WARNING: Failed to verify $package/$question setting"
    fi
}

# Parse command line arguments
EMAIL=""
LICENSE_KEY=""
USAGE_REPORTING=""
INSTALL_MODE=""
LICENSE_ACCEPTED=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --license-key)
            LICENSE_KEY="$2"
            shift 2
            ;;
        --usage-reporting)
            USAGE_REPORTING="$2"
            shift 2
            ;;
        --mode)
            INSTALL_MODE="$2"
            shift 2
            ;;
        --license-accepted)
            LICENSE_ACCEPTED="$2"
            shift 2
            ;;
        *)
            log_message "Unknown parameter: $1"
            shift
            ;;
    esac
done

log_message "Starting Kamiwaza debconf configuration..."
log_message "Email: $EMAIL"
log_message "License Key: ${LICENSE_KEY:0:10}..." # Only show first 10 chars for security
log_message "Usage Reporting: $USAGE_REPORTING"
log_message "Install Mode: $INSTALL_MODE"
log_message "License Accepted: $LICENSE_ACCEPTED"

# Ensure debconf is available
if ! command -v debconf-set-selections &> /dev/null; then
    log_message "Installing debconf-utils..."
    apt-get update -qq
    apt-get install -y debconf-utils
fi

# Set debconf values for Kamiwaza package
PACKAGE_NAME="kamiwaza"

# User email configuration
if [[ -n "$EMAIL" ]]; then
    set_debconf "$PACKAGE_NAME" "email" "string" "$EMAIL"
fi

# License key configuration
if [[ -n "$LICENSE_KEY" ]]; then
    set_debconf "$PACKAGE_NAME" "license-key" "password" "$LICENSE_KEY"
fi

# Usage reporting preference
if [[ -n "$USAGE_REPORTING" ]]; then
    # Convert to boolean format that debconf expects
    if [[ "$USAGE_REPORTING" == "1" || "$USAGE_REPORTING" == "true" ]]; then
        set_debconf "$PACKAGE_NAME" "usage-reporting" "boolean" "true"
    else
        set_debconf "$PACKAGE_NAME" "usage-reporting" "boolean" "false"
    fi
fi

# Installation mode
if [[ -n "$INSTALL_MODE" ]]; then
    set_debconf "$PACKAGE_NAME" "install-mode" "select" "$INSTALL_MODE"
fi

# License acceptance
if [[ -n "$LICENSE_ACCEPTED" ]]; then
    if [[ "$LICENSE_ACCEPTED" == "1" || "$LICENSE_ACCEPTED" == "true" ]]; then
        set_debconf "$PACKAGE_NAME" "license/accepted" "boolean" "true"
    else
        set_debconf "$PACKAGE_NAME" "license/accepted" "boolean" "false"
    fi
fi

# Set additional Kamiwaza-specific debconf values
set_debconf "$PACKAGE_NAME" "configured-by" "string" "windows-msi-installer"
set_debconf "$PACKAGE_NAME" "configuration-date" "string" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Create a debconf template file for Kamiwaza if it doesn't exist
TEMPLATES_FILE="/var/lib/dpkg/info/kamiwaza.templates"
if [[ ! -f "$TEMPLATES_FILE" ]]; then
    log_message "Creating debconf templates for Kamiwaza..."
    
    mkdir -p "$(dirname "$TEMPLATES_FILE")"
    cat > "$TEMPLATES_FILE" << 'EOF'
Template: kamiwaza/email
Type: string
Description: Email address for Kamiwaza account
 Please enter your email address for your Kamiwaza account.

Template: kamiwaza/license-key
Type: password
Description: Kamiwaza license key
 Please enter your Kamiwaza license key.

Template: kamiwaza/usage-reporting
Type: boolean
Default: true
Description: Enable usage reporting
 Help improve Kamiwaza by sending anonymous usage analytics.
 This helps us understand feature usage and improve performance.

Template: kamiwaza/install-mode
Type: select
Choices: lite, full, dev
Default: lite
Description: Installation mode
 Choose the Kamiwaza installation mode:
 .
 lite - Minimal installation for basic usage
 full - Complete installation with all features
 dev - Developer mode with debugging tools

Template: kamiwaza/license/accepted
Type: boolean
Description: License agreement acceptance
 Do you accept the Kamiwaza license agreement?

Template: kamiwaza/configured-by
Type: string
Description: Configuration source
 Source that configured this Kamiwaza installation.

Template: kamiwaza/configuration-date
Type: string
Description: Configuration timestamp
 When this Kamiwaza installation was configured.
EOF
    
    log_message "Created debconf templates file: $TEMPLATES_FILE"
fi

# Reconfigure debconf to pick up new templates
log_message "Updating debconf database..."
if command -v dpkg-reconfigure &> /dev/null; then
    dpkg-reconfigure -f noninteractive debconf 2>/dev/null || true
fi

# Display final configuration
log_message "Final debconf configuration for Kamiwaza:"
if command -v debconf-show &> /dev/null; then
    debconf-show kamiwaza 2>/dev/null | while read line; do
        # Mask sensitive information
        if echo "$line" | grep -q "license-key"; then
            echo "$line" | sed 's/\(license-key:\).*/\1 [REDACTED]/'
        else
            echo "$line"
        fi
    done | while read line; do
        log_message "  $line"
    done
fi

log_message "Kamiwaza debconf configuration completed successfully!"

# Export environment variables for potential use by installation scripts
export KAMIWAZA_EMAIL="$EMAIL"
export KAMIWAZA_LICENSE_KEY="$LICENSE_KEY"
export KAMIWAZA_USAGE_REPORTING="$USAGE_REPORTING"
export KAMIWAZA_INSTALL_MODE="$INSTALL_MODE"
export KAMIWAZA_LICENSE_ACCEPTED="$LICENSE_ACCEPTED"

log_message "Environment variables exported for installation process" 