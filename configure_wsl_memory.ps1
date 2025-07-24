# Configure WSL Memory for Kamiwaza
# This script creates or updates the .wslconfig file with Kamiwaza-specific memory settings

param(
    [Parameter(Mandatory=$true)]
    [string]$MemoryAmount
)

function Write-LogMessage {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN"  { "Yellow" }
            "INFO"  { "Green" }
            default { "White" }
        }
    )
}

Write-LogMessage "Starting WSL memory configuration for Kamiwaza..."
Write-LogMessage "Requested memory: $MemoryAmount"

# Validate memory format (should be like "14GB", "8GB", etc.)
if ($MemoryAmount -notmatch '^\d+GB$') {
    Write-LogMessage "Invalid memory format: $MemoryAmount. Expected format: XGB (e.g., 14GB)" "ERROR"
    exit 1
}

# Define .wslconfig path
$wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
Write-LogMessage "WSL config file path: $wslConfigPath"

# Create backup if file exists
if (Test-Path $wslConfigPath) {
    $backupPath = "$wslConfigPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $wslConfigPath $backupPath
    Write-LogMessage "Created backup: $backupPath"
}

# Read existing .wslconfig content
$existingConfig = @()
$wslSection = $false
$kamiwazaConfigured = $false

if (Test-Path $wslConfigPath) {
    $existingConfig = Get-Content $wslConfigPath
    Write-LogMessage "Read existing .wslconfig with $($existingConfig.Count) lines"
}

# Parse and update configuration
$newConfig = @()
$inWslSection = $false

foreach ($line in $existingConfig) {
    $trimmedLine = $line.Trim()
    
    # Check for [wsl2] section
    if ($trimmedLine -eq "[wsl2]") {
        $inWslSection = $true
        $newConfig += $line
        Write-LogMessage "Found [wsl2] section"
        continue
    }
    
    # Check for start of another section
    if ($trimmedLine.StartsWith("[") -and $trimmedLine.EndsWith("]") -and $trimmedLine -ne "[wsl2]") {
        # If we were in wsl2 section and haven't added memory, add it now
        if ($inWslSection -and -not $kamiwazaConfigured) {
            $newConfig += "# Kamiwaza dedicated memory configuration"
            $newConfig += "memory=$MemoryAmount"
            $kamiwazaConfigured = $true
            Write-LogMessage "Added Kamiwaza memory configuration to [wsl2] section"
        }
        $inWslSection = $false
        $newConfig += $line
        continue
    }
    
    # If we're in wsl2 section, check for existing settings
    if ($inWslSection) {
        if ($trimmedLine.StartsWith("memory=") -or $trimmedLine.StartsWith("#memory=")) {
            # Replace existing memory setting
            if (-not $kamiwazaConfigured) {
                $newConfig += "# Kamiwaza dedicated memory configuration"
                $newConfig += "memory=$MemoryAmount"
                $kamiwazaConfigured = $true
                Write-LogMessage "Replaced existing memory setting with Kamiwaza configuration"
            }
            continue
        }
        elseif ($trimmedLine.StartsWith("# Kamiwaza dedicated memory configuration") -or 
                $trimmedLine.StartsWith("# Additional Kamiwaza WSL optimizations")) {
            # Skip old Kamiwaza comments to avoid duplicates
            continue
        }
        elseif ($trimmedLine.StartsWith("processors=") -or 
                $trimmedLine.StartsWith("swap=") -or 
                $trimmedLine.StartsWith("localhostForwarding=")) {
            # Skip existing optimization settings that will be re-added if needed
            Write-LogMessage "Removing duplicate setting: $trimmedLine"
            continue
        }
    }
    
    $newConfig += $line
}

# If no [wsl2] section exists, create one
if (-not $inWslSection -and $existingConfig.Count -eq 0) {
    $newConfig += "[wsl2]"
    $newConfig += "# Kamiwaza dedicated memory configuration"
    $newConfig += "memory=$MemoryAmount"
    $kamiwazaConfigured = $true
    Write-LogMessage "Created new [wsl2] section with Kamiwaza memory configuration"
}
elseif ($inWslSection -and -not $kamiwazaConfigured) {
    # We ended in wsl2 section without adding memory
    $newConfig += "# Kamiwaza dedicated memory configuration"
    $newConfig += "memory=$MemoryAmount"
    $kamiwazaConfigured = $true
    Write-LogMessage "Added Kamiwaza memory configuration at end of [wsl2] section"
}

# Add additional WSL optimizations for Kamiwaza (if not already present)
if ($kamiwazaConfigured) {
    # Check if optimizations already exist
    $hasProcessors = $newConfig | Where-Object { $_.Trim().StartsWith("processors=") }
    $hasSwap = $newConfig | Where-Object { $_.Trim().StartsWith("swap=") }
    $hasLocalhost = $newConfig | Where-Object { $_.Trim().StartsWith("localhostForwarding=") }
    
    if (-not $hasProcessors -or -not $hasSwap -or -not $hasLocalhost) {
        # Find the memory line and add missing optimizations after it
        $optimizedConfig = @()
        $memoryLineFound = $false
        
        foreach ($line in $newConfig) {
            $optimizedConfig += $line
            
            if ($line.Trim() -eq "memory=$MemoryAmount" -and -not $memoryLineFound) {
                $memoryLineFound = $true
                $optimizedConfig += "# Additional Kamiwaza WSL optimizations"
                
                if (-not $hasProcessors) {
                    $optimizedConfig += "processors=4"
                    Write-LogMessage "Added processors optimization"
                }
                if (-not $hasSwap) {
                    $optimizedConfig += "swap=2GB"
                    Write-LogMessage "Added swap optimization"
                }
                if (-not $hasLocalhost) {
                    $optimizedConfig += "localhostForwarding=true"
                    Write-LogMessage "Added localhost forwarding optimization"
                }
            }
        }
        
        $newConfig = $optimizedConfig
    } else {
        Write-LogMessage "WSL optimizations already exist, skipping duplicate additions"
    }
}

# Write the updated configuration
try {
    $newConfig | Out-File -FilePath $wslConfigPath -Encoding UTF8
    Write-LogMessage "Successfully updated .wslconfig file"
    
    # Display the final configuration
    Write-LogMessage "Final .wslconfig content:"
    Get-Content $wslConfigPath | ForEach-Object { Write-LogMessage "  $_" }
    
    Write-LogMessage "WSL configuration completed successfully!" "INFO"
    Write-LogMessage "Please restart WSL for changes to take effect: wsl --shutdown" "WARN"
    
} catch {
    Write-LogMessage "Failed to write .wslconfig file: $($_.Exception.Message)" "ERROR"
    exit 1
}

exit 0 