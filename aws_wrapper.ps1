param(
    [string]$Operation,
    [string]$Version,
    [string]$Arch,
    [int]$StartBuild,
    [string]$EndpointUrl
)

# Function to check if a build exists
function Test-BuildExists {
    param([int]$BuildNumber)
    
    $fileName = "kamiwaza_installer_${Version}_${Arch}_build${BuildNumber}.exe"
    $result = & "venv\Scripts\aws.cmd" s3 ls "s3://k-ubuntu/$fileName" --endpoint-url $EndpointUrl 2>$null
    
    return $LASTEXITCODE -eq 0
}

# Function to upload files
function Upload-Files {
    param([int]$BuildNumber)
    
    $exeName = "kamiwaza_installer_${Version}_${Arch}_build${BuildNumber}.exe"
    $msiName = "kamiwaza_installer_${Version}_${Arch}_build${BuildNumber}.msi"
    
    Write-Host "[INFO] Uploading EXE: $exeName"
    & "venv\Scripts\aws.cmd" s3 cp "dist\kamiwaza_installer.exe" "s3://k-ubuntu/$exeName" --endpoint-url $EndpointUrl
    $exeSuccess = $LASTEXITCODE -eq 0
    
    Write-Host "[INFO] Uploading MSI: $msiName"
    & "venv\Scripts\aws.cmd" s3 cp "installer.msi" "s3://k-ubuntu/$msiName" --endpoint-url $EndpointUrl
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
        while ($currentBuild -le 50) {
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
        if ($currentBuild -gt 50) {
            Write-Host "[WARN] Safety limit reached at build $currentBuild"
            Write-Host "FINAL_BUILD_NUMBER=50"
        }
    }
    
    "upload" {
        Upload-Files -BuildNumber $StartBuild
    }
} 