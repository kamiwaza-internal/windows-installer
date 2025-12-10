param(
    [string]$Operation,
    [string]$Version,
    [string]$Arch,
    [int]$StartBuild,
    [string]$EndpointUrl,
    [switch]$SkipGeneric,
    [Parameter(Position=0, ValueFromRemainingArguments=$false)]
    [string]$FilePath
)

# Enhanced SSL configuration for PowerShell
$env:PYTHONHTTPSVERIFY = "0"
$env:AWS_CLI_SSL_NO_VERIFY = "true"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# Function to check if a build exists with fallback methods
function Test-BuildExists {
    param([int]$BuildNumber)
    
    $fileName = "kamiwaza_installer_${Version}_${Arch}.exe"
    
    # Method 1: Try AWS CLI with SSL bypass
    Write-Host "[DEBUG] Trying AWS CLI method for build check..."
    try {
        $result = & "venv\Scripts\aws.cmd" s3 ls "s3://packages/win/$fileName" --endpoint-url $EndpointUrl --no-verify-ssl 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[DEBUG] AWS CLI method succeeded"
            return $true
        }
    }
    catch {
        Write-Host "[DEBUG] AWS CLI method failed: $($_.Exception.Message)"
    }
    
    # Method 2: Try with additional AWS CLI options
    Write-Host "[DEBUG] Trying AWS CLI with additional SSL options..."
    try {
        $env:AWS_CA_BUNDLE = ""
        $result = & "venv\Scripts\aws.cmd" s3 ls "s3://packages/win/$fileName" --endpoint-url $EndpointUrl --no-verify-ssl --cli-read-timeout 30 --cli-connect-timeout 10 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[DEBUG] AWS CLI with additional options succeeded"
            return $true
        }
    }
    catch {
        Write-Host "[DEBUG] AWS CLI with additional options failed: $($_.Exception.Message)"
    }
    
    # Method 3: Try direct HTTP request (fallback)
    Write-Host "[DEBUG] Trying direct HTTP request method..."
    try {
        # Convert S3 URL to direct HTTP URL
        $baseUrl = $EndpointUrl -replace "https://([^/]+)", 'https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev'
        $directUrl = "$baseUrl/win/$fileName"
        
        Write-Host "[DEBUG] Checking URL: $directUrl"
        
        # Create a web request with SSL bypass
        $request = [System.Net.WebRequest]::Create($directUrl)
        $request.Method = "HEAD"
        $request.Timeout = 10000  # 10 seconds
        
        # Bypass SSL certificate validation
        if (-not ("TrustAllCertsPolicy" -as [type])) {
            Add-Type @"
                using System.Net;
                using System.Security.Cryptography.X509Certificates;
                public class TrustAllCertsPolicy : ICertificatePolicy {
                    public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
                        return true;
                    }
                }
"@
            [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
        }
        
        $response = $request.GetResponse()
        $response.Close()
        Write-Host "[DEBUG] Direct HTTP request succeeded - file exists"
        return $true
    }
    catch [System.Net.WebException] {
        $statusCode = $_.Exception.Response.StatusCode
        if ($statusCode -eq [System.Net.HttpStatusCode]::NotFound) {
            Write-Host "[DEBUG] Direct HTTP request: file not found (404)"
            return $false
        }
        else {
            Write-Host "[DEBUG] Direct HTTP request failed with status: $statusCode"
            return $false
        }
    }
    catch {
        Write-Host "[DEBUG] Direct HTTP request failed: $($_.Exception.Message)"
        return $false
    }
    
    # If all methods fail, assume file doesn't exist
    Write-Host "[DEBUG] All methods failed, assuming file doesn't exist"
    return $false
}

# Handle file path as unbound argument (when called like: script.ps1 upload filepath)
if (-not $FilePath -and $args.Count -gt 0) {
    $potentialPath = $args[0]
    if ($potentialPath -and (Test-Path $potentialPath -ErrorAction SilentlyContinue)) {
        $FilePath = $potentialPath
        Write-Host "[DEBUG] Detected file path from unbound argument: $FilePath"
    }
}

# Function to upload files with fallback methods
function Upload-Files {
    param([int]$BuildNumber)
    
    $exeName = "kamiwaza_installer_${Version}_${Arch}.exe"
    $msiName = "kamiwaza_installer_${Version}_${Arch}.msi"
    $genericMsiName = "kamiwaza_installer_${Version}_${Arch}.msi"
    
    $exeSuccess = $false
    $msiSuccess = $false
    $genericMsiSuccess = $false
    
    # Determine MSI source path and name
    $msiSourcePath = $null
    if ($FilePath -and (Test-Path $FilePath)) {
        $msiSourcePath = $FilePath
        $msiName = Split-Path -Leaf $FilePath
        Write-Host "[DEBUG] Using provided MSI file: $msiName"
    } else {
        # Check for renamed MSI file first (with build number), then fall back to default name
        $msiFiles = Get-ChildItem -Path "." -Filter "kamiwaza_installer_*.msi" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        if ($msiFiles -and $msiFiles.Count -gt 0) {
            $msiSourcePath = $msiFiles[0].FullName
            $msiName = $msiFiles[0].Name
            Write-Host "[DEBUG] Found renamed MSI file: $msiName"
        } elseif (Test-Path "kamiwaza_installer.msi") {
            $msiSourcePath = "kamiwaza_installer.msi"
        }
    }
    
    # Upload EXE (if exists)
    if (Test-Path "dist\kamiwaza_installer.exe") {
        Write-Host "[INFO] Uploading EXE: $exeName"
        
        # Method 1: AWS CLI with SSL bypass
        try {
            Write-Host "[DEBUG] Trying AWS CLI upload for EXE..."
            & "venv\Scripts\aws.cmd" s3 cp "dist\kamiwaza_installer.exe" "s3://packages/win/$exeName" --endpoint-url $EndpointUrl --no-verify-ssl
            $exeSuccess = $LASTEXITCODE -eq 0
            if ($exeSuccess) {
                Write-Host "[SUCCESS] EXE uploaded successfully via AWS CLI"
            }
        }
        catch {
            Write-Host "[ERROR] AWS CLI EXE upload failed: $($_.Exception.Message)"
        }
        
        # Method 2: Try with additional options if first method failed
        if (-not $exeSuccess) {
            try {
                Write-Host "[DEBUG] Trying AWS CLI EXE upload with additional options..."
                $env:AWS_CA_BUNDLE = ""
                & "venv\Scripts\aws.cmd" s3 cp "dist\kamiwaza_installer.exe" "s3://packages/win/$exeName" --endpoint-url $EndpointUrl --no-verify-ssl --cli-read-timeout 60 --cli-connect-timeout 20
                $exeSuccess = $LASTEXITCODE -eq 0
                if ($exeSuccess) {
                    Write-Host "[SUCCESS] EXE uploaded successfully via AWS CLI (with additional options)"
                }
            }
            catch {
                Write-Host "[ERROR] AWS CLI EXE upload with additional options failed: $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "[WARN] EXE file not found at dist\kamiwaza_installer.exe"
    }
    
    # Upload MSI
    if ($msiSourcePath -and (Test-Path $msiSourcePath)) {
        Write-Host "[INFO] Uploading MSI: $msiName from $msiSourcePath"
        
        # Method 1: AWS CLI with SSL bypass
        try {
            Write-Host "[DEBUG] Trying AWS CLI upload for MSI..."
            & "venv\Scripts\aws.cmd" s3 cp $msiSourcePath "s3://packages/win/$msiName" --endpoint-url $EndpointUrl --no-verify-ssl
            $msiSuccess = $LASTEXITCODE -eq 0
            if ($msiSuccess) {
                Write-Host "[SUCCESS] MSI uploaded successfully via AWS CLI"
            }
        }
        catch {
            Write-Host "[ERROR] AWS CLI MSI upload failed: $($_.Exception.Message)"
        }
        
        # Method 2: Try with additional options if first method failed
        if (-not $msiSuccess) {
            try {
                Write-Host "[DEBUG] Trying AWS CLI MSI upload with additional options..."
                $env:AWS_CA_BUNDLE = ""
                & "venv\Scripts\aws.cmd" s3 cp $msiSourcePath "s3://packages/win/$msiName" --endpoint-url $EndpointUrl --no-verify-ssl --cli-read-timeout 60 --cli-connect-timeout 20
                $msiSuccess = $LASTEXITCODE -eq 0
                if ($msiSuccess) {
                    Write-Host "[SUCCESS] MSI uploaded successfully via AWS CLI (with additional options)"
                }
            }
            catch {
                Write-Host "[ERROR] AWS CLI MSI upload with additional options failed: $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "[WARN] MSI file not found"
    }
    
    # Upload generic MSI (if MSI exists and not skipped)
    if ($SkipGeneric) {
        Write-Host "[INFO] Skipping generic MSI upload as requested"
        $genericMsiSuccess = $true  # Set to true since we're intentionally skipping
    } elseif ($msiSourcePath -and (Test-Path $msiSourcePath)) {
        Write-Host "[INFO] Uploading generic MSI: $genericMsiName from $msiSourcePath"
        
        # Method 1: AWS CLI with SSL bypass
        try {
            Write-Host "[DEBUG] Trying AWS CLI upload for generic MSI..."
            & "venv\Scripts\aws.cmd" s3 cp $msiSourcePath "s3://packages/win/$genericMsiName" --endpoint-url $EndpointUrl --no-verify-ssl
            $genericMsiSuccess = $LASTEXITCODE -eq 0
            if ($genericMsiSuccess) {
                Write-Host "[SUCCESS] Generic MSI uploaded successfully via AWS CLI"
            }
        }
        catch {
            Write-Host "[ERROR] AWS CLI generic MSI upload failed: $($_.Exception.Message)"
        }
        
        # Method 2: Try with additional options if first method failed
        if (-not $genericMsiSuccess) {
            try {
                Write-Host "[DEBUG] Trying AWS CLI generic MSI upload with additional options..."
                $env:AWS_CA_BUNDLE = ""
                & "venv\Scripts\aws.cmd" s3 cp $msiSourcePath "s3://packages/win/$genericMsiName" --endpoint-url $EndpointUrl --no-verify-ssl --cli-read-timeout 60 --cli-connect-timeout 20
                $genericMsiSuccess = $LASTEXITCODE -eq 0
                if ($genericMsiSuccess) {
                    Write-Host "[SUCCESS] Generic MSI uploaded successfully via AWS CLI (with additional options)"
                }
            }
            catch {
                Write-Host "[ERROR] AWS CLI generic MSI upload with additional options failed: $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "[WARN] MSI file not found for generic upload"
    }
    
    # Output results for batch script to read
    Write-Host "EXE_SUCCESS=$exeSuccess"
    Write-Host "MSI_SUCCESS=$msiSuccess"
    Write-Host "GENERIC_MSI_SUCCESS=$genericMsiSuccess"
    Write-Host "EXE_NAME=$exeName"
    Write-Host "MSI_NAME=$msiName"
    Write-Host "GENERIC_MSI_NAME=$genericMsiName"
    
    # Additional debug info
    if (-not $exeSuccess -and -not $msiSuccess) {
        Write-Host "[ERROR] Both uploads failed. Check AWS CLI configuration and network connectivity."
        Write-Host "[DEBUG] Endpoint URL: $EndpointUrl"
        Write-Host "[DEBUG] Working directory: $PWD"
    }
}

switch ($Operation) {
    "find-build" {
        $currentBuild = $StartBuild
        $maxAttempts = 50  # Prevent infinite loops
        $attempts = 0
        
        while ($attempts -lt $maxAttempts) {
            Write-Host "[INFO] Checking build $currentBuild... (attempt $($attempts + 1))"
            if (Test-BuildExists -BuildNumber $currentBuild) {
                Write-Host "[INFO] Build $currentBuild exists, trying next..."
                $currentBuild++
            } else {
                Write-Host "[SUCCESS] Using build $currentBuild for this release!"
                Write-Host "FINAL_BUILD_NUMBER=$currentBuild"
                break
            }
            $attempts++
        }
        
        if ($attempts -ge $maxAttempts) {
            Write-Host "[ERROR] Reached maximum attempts ($maxAttempts) for build number detection"
            Write-Host "FINAL_BUILD_NUMBER=$currentBuild"
        }
    }
    
    "upload" {
        Upload-Files -BuildNumber $StartBuild
    }
    
    default {
        Write-Host "[ERROR] Unknown operation: $Operation"
        Write-Host "[INFO] Valid operations: find-build, upload"
    }
}