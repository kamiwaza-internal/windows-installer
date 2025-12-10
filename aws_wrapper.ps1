param(
    [Parameter(Position=0)]
    [string]$Operation,
    [string]$Version,
    [string]$Arch,
    [int]$StartBuild = 0,
    [string]$EndpointUrl,
    [Parameter(Position=1, ValueFromRemainingArguments=$false)]
    [string]$FilePath
)

# Enhanced SSL configuration for PowerShell
$env:PYTHONHTTPSVERIFY = "0"
$env:AWS_CLI_SSL_NO_VERIFY = "true"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# Load defaults from config.yaml FIRST (before any other processing)
$configVersion = $null
$configArch = $null
$configEndpointUrl = $null
$configBuildNumber = $null

if (Test-Path "config.yaml") {
    Write-Host "[DEBUG] Loading configuration from config.yaml..."
    $configContent = Get-Content "config.yaml" -Raw
    
    if ($configContent -match 'kamiwaza_version:\s*([^\s#]+)') {
        $configVersion = $matches[1].Trim()
        Write-Host "[DEBUG] Found version in config: $configVersion"
    }
    if ($configContent -match 'arch:\s*([^\s#]+)') {
        $configArch = $matches[1].Trim()
        Write-Host "[DEBUG] Found architecture in config: $configArch"
    }
    if ($configContent -match 'r2_endpoint_url:\s*([^\s#]+)') {
        $configEndpointUrl = $matches[1].Trim()
        Write-Host "[DEBUG] Found endpoint URL in config"
    }
    if ($configContent -match 'build_number:\s*([^\s#]+)') {
        $configBuildNumber = [int]$matches[1].Trim()
        Write-Host "[DEBUG] Found build number in config: $configBuildNumber"
    }
} else {
    Write-Host "[DEBUG] config.yaml not found, using command-line parameters only"
}

# Apply config.yaml values as defaults (only if not provided via command-line)
if (-not $Version -and $configVersion) {
    $Version = $configVersion
    Write-Host "[DEBUG] Using version from config.yaml: $Version"
}
if (-not $Arch -and $configArch) {
    $Arch = $configArch
    Write-Host "[DEBUG] Using architecture from config.yaml: $Arch"
}
if (-not $EndpointUrl -and $configEndpointUrl) {
    $EndpointUrl = $configEndpointUrl
    Write-Host "[DEBUG] Using endpoint URL from config.yaml"
}
if ($StartBuild -eq 0 -and $configBuildNumber) {
    $StartBuild = $configBuildNumber
    Write-Host "[DEBUG] Using build number from config.yaml: $StartBuild"
}

# Handle file path as unbound argument (when called like: script.ps1 upload filepath)
if (-not $FilePath -and $args.Count -gt 0) {
    $potentialPath = $args[0]
    if ($potentialPath -and (Test-Path $potentialPath -ErrorAction SilentlyContinue)) {
        $FilePath = $potentialPath
        Write-Host "[DEBUG] Detected file path from unbound argument: $FilePath"
    }
}

# Parse file path if provided (for direct file upload)
# Filename extraction will override config.yaml values if file path is provided
if ($FilePath -and $Operation -eq "upload") {
    Write-Host "[DEBUG] File path provided: $FilePath"
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "[ERROR] File not found: $FilePath"
        exit 1
    }
    
    $fileName = Split-Path -Leaf $FilePath
    Write-Host "[DEBUG] Extracted filename: $fileName"
    
    # Parse filename pattern: kamiwaza_installer_<version>_<arch>.<ext>
    if ($fileName -match 'kamiwaza_installer_([^_]+)_([^.]+)\.(msi|exe)') {
        # Filename values override config.yaml and command-line (if not explicitly provided)
        if (-not $Version -or $Version -eq $configVersion) {
            $Version = $matches[1]
            Write-Host "[DEBUG] Extracted version from filename: $Version"
        }
        if (-not $Arch -or $Arch -eq $configArch) {
            $Arch = $matches[2]
            Write-Host "[DEBUG] Extracted architecture from filename: $Arch"
        }
        $fileExtension = $matches[3]
        Write-Host "[DEBUG] File extension: $fileExtension"
    } else {
        Write-Host "[ERROR] Filename does not match expected pattern: kamiwaza_installer_<version>_<arch>.<ext>"
        Write-Host "[ERROR] Got: $fileName"
        exit 1
    }
    
    # Store file path and extension for use in upload function
    $script:SourceFilePath = $FilePath
    $script:SourceFileExtension = $fileExtension
} else {
    $script:SourceFilePath = $null
    $script:SourceFileExtension = $null
}

# Function to check if a build exists with fallback methods
function Test-BuildExists {
    param([int]$BuildNumber)
    
    $fileName = "kamiwaza_installer_${Version}_${Arch}.exe"
    
    # Method 1: Try AWS CLI with SSL bypass
    Write-Host "[DEBUG] Trying AWS CLI method for build check..."
    try {
        $result = & "venv\Scripts\aws.cmd" s3 ls "s3://k-ubuntu/$fileName" --endpoint-url $EndpointUrl --no-verify-ssl 2>$null
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
        $result = & "venv\Scripts\aws.cmd" s3 ls "s3://k-ubuntu/$fileName" --endpoint-url $EndpointUrl --no-verify-ssl --cli-read-timeout 30 --cli-connect-timeout 10 2>$null
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
        $directUrl = "$baseUrl/$fileName"
        
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

# Function to upload files with fallback methods
function Upload-Files {
    param([int]$BuildNumber)
    
    $exeName = "kamiwaza_installer_${Version}_${Arch}.exe"
    $msiName = "kamiwaza_installer_${Version}_${Arch}.msi"
    
    $exeSuccess = $false
    $msiSuccess = $false
    
    # Determine source file paths
    $exeSourcePath = $null
    $msiSourcePath = $null
    
    if ($script:SourceFilePath) {
        # Use provided file path
        if ($script:SourceFileExtension -eq "exe") {
            $exeSourcePath = $script:SourceFilePath
            # Use the actual filename for upload target
            $exeName = Split-Path -Leaf $script:SourceFilePath
        } elseif ($script:SourceFileExtension -eq "msi") {
            $msiSourcePath = $script:SourceFilePath
            # Use the actual filename for upload target
            $msiName = Split-Path -Leaf $script:SourceFilePath
        }
    } else {
        # Use default paths
        if (Test-Path "dist\kamiwaza_installer.exe") {
            $exeSourcePath = "dist\kamiwaza_installer.exe"
        }
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
    if ($exeSourcePath -and (Test-Path $exeSourcePath)) {
        Write-Host "[INFO] Uploading EXE: $exeName from $exeSourcePath"
        
        # Method 1: AWS CLI with SSL bypass
        try {
            Write-Host "[DEBUG] Trying AWS CLI upload for EXE..."
            & "venv\Scripts\aws.cmd" s3 cp $exeSourcePath "s3://k-ubuntu/$exeName" --endpoint-url $EndpointUrl --no-verify-ssl
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
                & "venv\Scripts\aws.cmd" s3 cp $exeSourcePath "s3://k-ubuntu/$exeName" --endpoint-url $EndpointUrl --no-verify-ssl --cli-read-timeout 60 --cli-connect-timeout 20
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
        Write-Host "[WARN] EXE file not found"
    }
    
    # Upload MSI
    if ($msiSourcePath -and (Test-Path $msiSourcePath)) {
        Write-Host "[INFO] Uploading MSI: $msiName from $msiSourcePath"
        
        # Method 1: AWS CLI with SSL bypass
        try {
            Write-Host "[DEBUG] Trying AWS CLI upload for MSI..."
            & "venv\Scripts\aws.cmd" s3 cp $msiSourcePath "s3://k-ubuntu/$msiName" --endpoint-url $EndpointUrl --no-verify-ssl
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
                & "venv\Scripts\aws.cmd" s3 cp $msiSourcePath "s3://k-ubuntu/$msiName" --endpoint-url $EndpointUrl --no-verify-ssl --cli-read-timeout 60 --cli-connect-timeout 20
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
    
    # Output results for batch script to read
    Write-Host "EXE_SUCCESS=$exeSuccess"
    Write-Host "MSI_SUCCESS=$msiSuccess"
    Write-Host "EXE_NAME=$exeName"
    Write-Host "MSI_NAME=$msiName"
    
    # Additional debug info
    if (-not $exeSuccess -and -not $msiSuccess) {
        Write-Host "[ERROR] Both uploads failed. Check AWS CLI configuration and network connectivity."
        Write-Host "[DEBUG] Endpoint URL: $EndpointUrl"
        Write-Host "[DEBUG] Working directory: $PWD"
    }
}

# Validate required parameters for upload operation
if ($Operation -eq "upload") {
    if (-not $Version) {
        Write-Host "[ERROR] Version is required. Provide -Version parameter or ensure config.yaml contains kamiwaza_version"
        exit 1
    }
    if (-not $Arch) {
        Write-Host "[ERROR] Architecture is required. Provide -Arch parameter or ensure config.yaml contains arch"
        exit 1
    }
    if (-not $EndpointUrl) {
        Write-Host "[ERROR] Endpoint URL is required. Provide -EndpointUrl parameter or ensure config.yaml contains r2_endpoint_url"
        exit 1
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