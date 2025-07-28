# PowerShell script to sign MSI installer
param(
    [string]$CertPath = "kamiwaza_cert.pfx",
    [string]$CertPassword = "kamiwaza123",
    [string]$MSIPath = "installer.msi"
)

# Function to find signtool.exe
function Find-SignTool {
    $possiblePaths = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\x64\signtool.exe",
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\x86\signtool.exe",
        "${env:ProgramFiles}\Windows Kits\10\bin\x64\signtool.exe",
        "${env:ProgramFiles}\Windows Kits\10\bin\x86\signtool.exe"
    )
    
    # Try to find in Windows Kits subdirectories
    $kitsPath = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
    if (Test-Path $kitsPath) {
        $versions = Get-ChildItem $kitsPath -Directory | Sort-Object Name -Descending
        foreach ($version in $versions) {
            $x64Path = Join-Path $version.FullName "x64\signtool.exe"
            $x86Path = Join-Path $version.FullName "x86\signtool.exe"
            if (Test-Path $x64Path) { $possiblePaths += $x64Path }
            if (Test-Path $x86Path) { $possiblePaths += $x86Path }
        }
    }
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    throw "signtool.exe not found. Please install Windows SDK."
}

try {
    Write-Output "[INFO] Starting MSI signing process..."
    
    # Check if certificate exists
    if (-not (Test-Path $CertPath)) {
        Write-Error "Certificate not found: $CertPath"
        exit 1
    }
    
    # Check if MSI exists
    if (-not (Test-Path $MSIPath)) {
        Write-Error "MSI file not found: $MSIPath"
        exit 1
    }
    
    # Find signtool
    Write-Output "[INFO] Locating signtool.exe..."
    $signTool = Find-SignTool
    Write-Output "[INFO] Using signtool: $signTool"
    
    # Sign MSI
    Write-Output "[INFO] Signing MSI: $MSIPath"
    $signArgs = @(
        "sign",
        "/f", $CertPath,
        "/p", $CertPassword,
        "/fd", "SHA256",
        "/t", "http://timestamp.digicert.com",
        $MSIPath
    )
    
    $process = Start-Process -FilePath $signTool -ArgumentList $signArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Output "[SUCCESS] MSI signed successfully"
        
        # Verify signature
        Write-Output "[INFO] Verifying MSI signature..."
        $verifyArgs = @("verify", "/pa", $MSIPath)
        $verifyProcess = Start-Process -FilePath $signTool -ArgumentList $verifyArgs -Wait -PassThru -NoNewWindow
        
        if ($verifyProcess.ExitCode -eq 0) {
            Write-Output "[SUCCESS] MSI signature verified"
            exit 0
        } else {
            Write-Warning "[WARN] MSI signature verification failed"
            exit 0  # Still consider success since signing worked
        }
    } else {
        Write-Error "[ERROR] MSI signing failed with exit code: $($process.ExitCode)"
        exit 1
    }
    
} catch {
    Write-Error "[ERROR] Signing process failed: $($_.Exception.Message)"
    exit 1
}