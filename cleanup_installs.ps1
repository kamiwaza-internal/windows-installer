# Kamiwaza Installation Cleanup Script - PowerShell Version
# Requires Administrator privileges

param(
    [switch]$Force,
    [switch]$Quiet
)

# Setup logging
$logFile = "$env:TEMP\kamiwaza_uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log {
    param([string]$Message, [string]$Type = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Type] $Message"
    Add-Content -Path $logFile -Value $logEntry
    
    # Also write to console if not quiet
    if (-not $Quiet) {
        $color = switch ($Type) {
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            default { "White" }
        }
        Write-Host "[$Type] $Message" -ForegroundColor $color
    }
}

function Write-Status {
    param([string]$Message, [string]$Type = "INFO")
    Write-Log -Message $Message -Type $Type
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check for admin privileges
if (-not (Test-Administrator)) {
    Write-Status "This script requires Administrator privileges!" "ERROR"
    Write-Status "Please run PowerShell as Administrator and try again." "ERROR"
    if (-not $Quiet) { Read-Host "Press Enter to exit" }
    exit 1
}

Write-Status "Kamiwaza Installation Cleanup Script" "INFO"
Write-Status "Log file: $logFile" "INFO"
Write-Status "Running with Administrator privileges..." "SUCCESS"
Write-Status "Starting comprehensive cleanup process..." "INFO"
Write-Host ""

# 1. Find and uninstall MSI packages
Write-Status "=== Step 1: Finding and Uninstalling MSI Packages ===" "INFO"

try {
    # Find Kamiwaza installations using WMI
    $installedProducts = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Kamiwaza*" }
    
    if ($installedProducts) {
        foreach ($product in $installedProducts) {
            Write-Status "Found: $($product.Name) (Version: $($product.Version))" "INFO"
            Write-Status "Product Code: $($product.IdentifyingNumber)" "INFO"
            
            try {
                Write-Status "Uninstalling $($product.Name)..." "INFO"
                $result = $product.Uninstall()
                if ($result.ReturnValue -eq 0) {
                    Write-Status "Successfully uninstalled $($product.Name)" "SUCCESS"
                } else {
                    Write-Status "Uninstall failed with code: $($result.ReturnValue)" "WARNING"
                }
            } catch {
                Write-Status "Error uninstalling $($product.Name): $($_.Exception.Message)" "ERROR"
            }
        }
    } else {
        Write-Status "No Kamiwaza installations found via WMI" "INFO"
    }
    
    # Try uninstalling via local MSI file
    if (Test-Path "installer.msi") {
        Write-Status "Found local installer.msi, attempting uninstall..." "INFO"
        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x", "installer.msi", "/quiet", "/norestart" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Status "Successfully uninstalled via installer.msi" "SUCCESS"
        } else {
            Write-Status "Uninstall via installer.msi failed (exit code: $($process.ExitCode))" "WARNING"
        }
    }
} catch {
    Write-Status "Error during MSI uninstall: $($_.Exception.Message)" "ERROR"
}

Write-Host ""

# 2. Clean MSI Cache
Write-Status "=== Step 2: Cleaning MSI Cache ===" "INFO"

$msiCachePath = "$env:SystemRoot\Installer"
if (Test-Path $msiCachePath) {
    try {
        $msiFiles = Get-ChildItem -Path $msiCachePath -Filter "*.msi" | Where-Object { $_.Name -like "*kamiwaza*" -or (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -like "*kamiwaza*" }
        
        foreach ($file in $msiFiles) {
            try {
                Write-Status "Removing MSI cache file: $($file.Name)" "INFO"
                Remove-Item $file.FullName -Force
                Write-Status "Removed: $($file.Name)" "SUCCESS"
            } catch {
                Write-Status "Could not remove $($file.Name): $($_.Exception.Message)" "WARNING"
            }
        }
        
        if (-not $msiFiles) {
            Write-Status "No Kamiwaza MSI files found in cache" "INFO"
        }
    } catch {
        Write-Status "Error cleaning MSI cache: $($_.Exception.Message)" "ERROR"
    }
}

# Clean temp files
try {
    Remove-Item "$env:TEMP\*.msi" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\kamiwaza*" -Force -Recurse -ErrorAction SilentlyContinue
    Write-Status "Cleaned temporary MSI files" "SUCCESS"
} catch {
    Write-Status "Could not clean all temp files: $($_.Exception.Message)" "WARNING"
}

Write-Host ""

# 3. Clean Registry
Write-Status "=== Step 3: Cleaning Registry ===" "INFO"

$registryPaths = @(
    "HKLM:\SOFTWARE\Kamiwaza",
    "HKLM:\SOFTWARE\WOW6432Node\Kamiwaza",
    "HKCU:\SOFTWARE\Kamiwaza"
)

foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        try {
            Remove-Item $path -Recurse -Force
            Write-Status "Removed registry key: $path" "SUCCESS"
        } catch {
            Write-Status "Could not remove registry key $path: $($_.Exception.Message)" "WARNING"
        }
    } else {
        Write-Status "Registry key not found: $path" "INFO"
    }
}

# Clean uninstall entries
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

foreach ($uninstallPath in $uninstallPaths) {
    try {
        $entries = Get-ChildItem $uninstallPath -ErrorAction SilentlyContinue | Where-Object { 
            $_.GetValue("DisplayName") -like "*Kamiwaza*" 
        }
        
        foreach ($entry in $entries) {
            try {
                Write-Status "Removing uninstall entry: $($entry.GetValue('DisplayName'))" "INFO"
                Remove-Item $entry.PSPath -Recurse -Force
                Write-Status "Removed uninstall entry" "SUCCESS"
            } catch {
                Write-Status "Could not remove uninstall entry: $($_.Exception.Message)" "WARNING"
            }
        }
    } catch {
        Write-Status "Error cleaning uninstall entries: $($_.Exception.Message)" "ERROR"
    }
}

Write-Host ""

# 4. Clean Program Files
Write-Status "=== Step 4: Cleaning Program Files ===" "INFO"

$installDirs = @(
    "$env:ProgramFiles\Kamiwaza",
    "${env:ProgramFiles(x86)}\Kamiwaza",
    "$env:LocalAppData\Kamiwaza",
    "$env:AppData\Kamiwaza",
    "C:\Users\appii\AppData\Local\Kamiwaza"
)

foreach ($dir in $installDirs) {
    if (Test-Path $dir) {
        try {
            Write-Status "Removing directory: $dir" "INFO"
            Remove-Item $dir -Recurse -Force
            Write-Status "Removed: $dir" "SUCCESS"
        } catch {
            Write-Status "Could not remove $dir: $($_.Exception.Message)" "WARNING"
            Write-Status "Some files may be in use. Try again after restart." "INFO"
        }
    } else {
        Write-Status "Directory not found: $dir" "INFO"
    }
}

Write-Host ""

# 5. Clean Shortcuts
Write-Status "=== Step 5: Cleaning Shortcuts ===" "INFO"

$shortcutLocations = @(
    "$env:Public\Desktop\Kamiwaza*",
    "$env:UserProfile\Desktop\Kamiwaza*",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Kamiwaza*",
    "$env:AppData\Microsoft\Windows\Start Menu\Programs\Kamiwaza*"
)

foreach ($location in $shortcutLocations) {
    try {
        $shortcuts = Get-Item $location -ErrorAction SilentlyContinue
        foreach ($shortcut in $shortcuts) {
            Remove-Item $shortcut -Force
            Write-Status "Removed shortcut: $($shortcut.Name)" "SUCCESS"
        }
    } catch {
        # Silently continue if no shortcuts found
    }
}

# Remove start menu folders
$startMenuFolders = @(
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Kamiwaza",
    "$env:AppData\Microsoft\Windows\Start Menu\Programs\Kamiwaza"
)

foreach ($folder in $startMenuFolders) {
    if (Test-Path $folder) {
        try {
            Remove-Item $folder -Recurse -Force
            Write-Status "Removed start menu folder: $folder" "SUCCESS"
        } catch {
            Write-Status "Could not remove start menu folder: $($_.Exception.Message)" "WARNING"
        }
    }
}

Write-Host ""

# 6. Clean WSL Distribution
Write-Status "=== Step 6: Cleaning WSL Distribution ===" "INFO"

try {
    # Check if kamiwaza WSL distribution exists
    $wslList = wsl --list --quiet 2>$null
    if ($wslList -contains "kamiwaza") {
        Write-Status "Found WSL distribution 'kamiwaza', unregistering..." "INFO"
        $process = Start-Process -FilePath "wsl" -ArgumentList "--unregister", "kamiwaza" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Write-Status "Successfully unregistered WSL distribution 'kamiwaza'" "SUCCESS"
        } else {
            Write-Status "Failed to unregister WSL distribution (exit code: $($process.ExitCode))" "WARNING"
        }
    } else {
        Write-Status "WSL distribution 'kamiwaza' not found" "INFO"
    }
} catch {
    Write-Status "Error during WSL cleanup: $($_.Exception.Message)" "WARNING"
}

Write-Host ""

# 7. Restart Windows Installer Service
Write-Status "=== Step 7: Restarting Windows Installer Service ===" "INFO"

try {
    Stop-Service -Name "msiserver" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Service -Name "msiserver"
    Write-Status "Windows Installer service restarted" "SUCCESS"
} catch {
    Write-Status "Could not restart Windows Installer service: $($_.Exception.Message)" "WARNING"
}

Write-Host ""

# 8. Final Verification
Write-Status "=== Step 8: Final Verification ===" "INFO"

try {
    $remainingProducts = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*Kamiwaza*" }
    if ($remainingProducts) {
        Write-Status "WARNING: Some Kamiwaza installations still found:" "WARNING"
        foreach ($product in $remainingProducts) {
            Write-Status "  - $($product.Name) (Version: $($product.Version))" "WARNING"
        }
    } else {
        Write-Status "No remaining Kamiwaza installations found" "SUCCESS"
    }
} catch {
    Write-Status "Could not verify cleanup completion: $($_.Exception.Message)" "WARNING"
}

Write-Host ""
Write-Status "=== CLEANUP COMPLETE ===" "SUCCESS"
Write-Status "All Kamiwaza installation traces have been removed." "SUCCESS"
Write-Status "You may need to restart your computer for all changes to take effect." "INFO"
Write-Status "Cleanup log saved to: $logFile" "INFO"

if (-not $Quiet) {
    Write-Host ""
    Read-Host "Press Enter to exit"
} 