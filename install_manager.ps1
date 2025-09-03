# Install Kamiwaza GUI Manager to AppData and Start Menu
# This script is called by the MSI installer

param(
    [switch]$CreateDesktopShortcut
)

Write-Host "Installing Kamiwaza GUI Manager..." -ForegroundColor Green

# Get the source executable path (from MSI installer)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceExe = Join-Path $scriptDir "KamiwazaManager.exe"
$targetDir = Join-Path $env:LOCALAPPDATA "Kamiwaza"
$startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Kamiwaza"

# Create target directories
if (!(Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}
if (!(Test-Path $startMenuDir)) {
    New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
}

# Copy the executable
if (Test-Path $sourceExe) {
    Copy-Item $sourceExe $targetDir -Force
    Write-Host "Copied GUI Manager to: $targetDir" -ForegroundColor Green
    
    # Create Start Menu shortcut using WScript.Shell
    try {
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut("$startMenuDir\Kamiwaza Manager.lnk")
        $shortcut.TargetPath = "$targetDir\KamiwazaManager.exe"
        $shortcut.WorkingDirectory = $targetDir
        $shortcut.Description = "Kamiwaza Manager - GUI Management Tool"
        $shortcut.IconLocation = "$targetDir\KamiwazaManager.exe,0"
        $shortcut.Save()
        Write-Host "Created Start Menu shortcut" -ForegroundColor Green
        
        # Create desktop shortcut if requested
        if ($CreateDesktopShortcut) {
            $desktopDir = [Environment]::GetFolderPath("Desktop")
            if (Test-Path $desktopDir) {
                $desktopShortcut = $WshShell.CreateShortcut("$desktopDir\Kamiwaza Manager.lnk")
                $desktopShortcut.TargetPath = "$targetDir\KamiwazaManager.exe"
                $desktopShortcut.WorkingDirectory = $targetDir
                $desktopShortcut.Description = "Kamiwaza Manager - GUI Management Tool"
                $desktopShortcut.IconLocation = "$targetDir\KamiwazaManager.exe,0"
                $desktopShortcut.Save()
                Write-Host "Created desktop shortcut" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Warning "Could not create shortcuts: $_"
        # Fallback: create batch file shortcuts
        $batchContent = "@echo off`nstart `"`" `"$targetDir\KamiwazaManager.exe`""
        Set-Content -Path "$startMenuDir\Kamiwaza Manager.bat" -Value $batchContent
        Write-Host "Created batch file shortcut as fallback" -ForegroundColor Yellow
    }
    
    Write-Host "GUI Manager installation completed successfully!" -ForegroundColor Green
} else {
    Write-Error "Source executable not found: $sourceExe"
    exit 1
}

Write-Host ""
Write-Host "Kamiwaza Manager is now available:" -ForegroundColor Cyan
Write-Host "- Start Menu: Start > Kamiwaza > Kamiwaza Manager" -ForegroundColor White
Write-Host "- Direct path: $targetDir\KamiwazaManager.exe" -ForegroundColor White
Write-Host ""
Write-Host "You can now use the GUI to manage your Kamiwaza installation!" -ForegroundColor Green
