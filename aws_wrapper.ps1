param(
    [string]$Operation,
    [string]$Version,
    [string]$Arch,
    [int]$StartBuild,
    [string]$EndpointUrl
)

# Set environment variables to help with SSL/TLS issues
$env:PYTHONHTTPSVERIFY = "0"
$env:AWS_CLI_SSL_NO_VERIFY = "true"

# Additional SSL configuration
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# Function to check if a build exists
function Test-BuildExists {
    param([int]$BuildNumber)
    
    $fileName = "kamiwaza_installer_${Version}_${Arch}_build${BuildNumber}.exe"
    $result = & "venv\Scripts\aws.cmd" s3 ls "s3://k-ubuntu/$fileName" --endpoint-url $EndpointUrl --no-verify-ssl 2>$null
    
    return $LASTEXITCODE -eq 0
}

# Function to upload files
function Upload-Files {
    param([int]$BuildNumber)
    
    $exeName = "kamiwaza_installer_${Version}_${Arch}_build${BuildNumber}.exe"
    $msiName = "kamiwaza_installer_${Version}_${Arch}_build${BuildNumber}.msi"
    
    Write-Host "[INFO] Uploading EXE: $exeName"
    & "venv\Scripts\aws.cmd" s3 cp "dist\kamiwaza_installer.exe" "s3://k-ubuntu/$exeName" --endpoint-url $EndpointUrl --no-verify-ssl
    $exeSuccess = $LASTEXITCODE -eq 0
    
    Write-Host "[INFO] Uploading MSI: $msiName"
    & "venv\Scripts\aws.cmd" s3 cp "kamiwaza_installer.msi" "s3://k-ubuntu/$msiName" --endpoint-url $EndpointUrl --no-verify-ssl
    $msiSuccess = $LASTEXITCODE -eq 0
    
    # Output results for batch script to read
    Write-Host "EXE_SUCCESS=$exeSuccess"
    Write-Host "MSI_SUCCESS=$msiSuccess"
    Write-Host "EXE_NAME=$exeName"
    Write-Host "MSI_NAME=$msiName"
}

switch ($Operation) {
    "find-build" {
        $currentBuild = $StartBuild
        while ($true) {
            Write-Host "[INFO] Checking build $currentBuild..."
            if (Test-BuildExists -BuildNumber $currentBuild) {
                Write-Host "[INFO] Build $currentBuild exists, trying next..."
                $currentBuild++
            } else {
                Write-Host "[SUCCESS] Using build $currentBuild for this release!"
                Write-Host "FINAL_BUILD_NUMBER=$currentBuild"
                break
            }
        }
    }
    
    "upload" {
        Upload-Files -BuildNumber $StartBuild
    }
} 