param(
    [Parameter(Mandatory=$false)]
    [string]$MsiFilePath,
    
    [string]$EnvFile = "",
    
    [switch]$Delete,
    [string]$Version = "",
    [string]$Arch = ""
)

# Auto-detect environment file location
if ([string]::IsNullOrWhiteSpace($EnvFile)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $EnvFile = Join-Path $scriptDir "env.sh"
}

# Enhanced SSL configuration for PowerShell
$env:PYTHONHTTPSVERIFY = "0"
$env:AWS_CLI_SSL_NO_VERIFY = "true"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# Function to load environment variables from file
function Load-EnvFile {
    param([string]$FilePath)
    
    Write-Host "`[INFO`] Loading environment variables from: $FilePath"
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "`[ERROR`] Environment file not found: $FilePath"
        Write-Host "`[INFO`] Please create the environment file with your AWS credentials"
        Write-Host "`[INFO`] Expected format:"
        Write-Host "       AWS_ACCESS_KEY_ID=your_access_key"
        Write-Host "       AWS_SECRET_ACCESS_KEY=your_secret_key"
        Write-Host "       AWS_ENDPOINT_URL=your_endpoint_url"
        Write-Host "       BUCKET_NAME=your_bucket_name"
        Write-Host ""
        Write-Host "`[DEBUG`] Script completed. Press any key to close..."
        Read-Host
        exit 1
    }
    
    $envVars = @{}
    
    try {
        $content = Get-Content $FilePath -ErrorAction Stop
        foreach ($line in $content) {
            # Skip empty lines and comments
            if ($line -match '^\s*$' -or $line -match '^\s*#') {
                continue
            }
            
            # Parse KEY=VALUE format (handle export keyword)
            if ($line -match '^(?:export\s+)?([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # Remove quotes if present
                $value = $value -replace '^["'']|["'']$', ''
                
                $envVars[$key] = $value
                Write-Host "`[DEBUG`] Loaded: $key = $value"
            }
        }
        
        Write-Host "`[SUCCESS`] Environment variables loaded successfully"
        return $envVars
    }
    catch {
        Write-Host "`[ERROR`] Failed to load environment file: $($_.Exception.Message)"
        Write-Host ""
        Write-Host "`[DEBUG`] Script completed. Press any key to close..."
        Read-Host
        exit 1
    }
}

# Function to set environment variables
function Set-AwsEnvironment {
    param([hashtable]$EnvVars)
    
    Write-Host "`[INFO`] Setting AWS environment variables..."
    
    # Required variables
    $requiredVars = @('AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_ENDPOINT_URL', 'BUCKET_NAME')
    
    foreach ($var in $requiredVars) {
        if (-not $EnvVars.ContainsKey($var) -or [string]::IsNullOrWhiteSpace($EnvVars[$var])) {
            Write-Host "`[ERROR`] Required environment variable missing or empty: $var"
            Write-Host "`[INFO`] Please ensure your environment file contains all required variables"
            Write-Host ""
            Write-Host "`[DEBUG`] Script completed. Press any key to close..."
            Read-Host
            exit 1
        }
        
        Set-Item -Path "env:$var" -Value $EnvVars[$var]
        Write-Host "`[DEBUG`] Set $var = $($EnvVars[$var])"
    }
    
    Write-Host "`[SUCCESS`] AWS environment configured"
}

# Function to upload MSI with fallback methods
function Upload-MsiFile {
    param(
        [string]$SourceFile,
        [string]$TargetName,
        [string]$BucketName,
        [string]$EndpointUrl
    )
    
    Write-Host "`[INFO`] Uploading MSI: $TargetName"
    Write-Host "`[DEBUG`] Source: $SourceFile"
    Write-Host "`[DEBUG`] Target: s3://$BucketName/win/$TargetName"
    Write-Host "`[DEBUG`] Endpoint: $EndpointUrl"
    
    $uploadSuccess = $false
    
    # Method 1: Try AWS CLI with SSL bypass
    try {
        Write-Host "`[DEBUG`] Attempting AWS CLI upload..."
        $awsCmd = "aws"
        if (Test-Path "venv\Scripts\aws.cmd") {
            $awsCmd = "venv\Scripts\aws.cmd"
            Write-Host "`[DEBUG`] Using virtual environment AWS CLI"
        }
        
        & $awsCmd s3 cp $SourceFile "s3://$BucketName/win/$TargetName" --endpoint-url $EndpointUrl --no-verify-ssl
        
        if ($LASTEXITCODE -eq 0) {
            $uploadSuccess = $true
            Write-Host "`[SUCCESS`] Upload completed successfully via AWS CLI"
        } else {
            Write-Host "`[ERROR`] AWS CLI upload failed with exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Host "`[ERROR`] AWS CLI upload failed: $($_.Exception.Message)"
    }
    
    # Method 2: Try with additional AWS CLI options if first method failed
    if (-not $uploadSuccess) {
        try {
            Write-Host "`[DEBUG`] Attempting AWS CLI upload with additional options..."
            $env:AWS_CA_BUNDLE = ""
            
            & $awsCmd s3 cp $SourceFile "s3://$BucketName/win/$TargetName" --endpoint-url $EndpointUrl --no-verify-ssl --cli-read-timeout 60 --cli-connect-timeout 20
            
            if ($LASTEXITCODE -eq 0) {
                $uploadSuccess = $true
                Write-Host "`[SUCCESS`] Upload completed successfully via AWS CLI (with additional options)"
            } else {
                Write-Host "`[ERROR`] AWS CLI upload with additional options failed with exit code: $LASTEXITCODE"
            }
        }
        catch {
            Write-Host "`[ERROR`] AWS CLI upload with additional options failed: $($_.Exception.Message)"
        }
    }
    
    return $uploadSuccess
}

# Function to delete MSI files
function Delete-MsiFiles {
    param(
        [string]$Version,
        [string]$Arch,
        [string]$BucketName,
        [string]$EndpointUrl
    )
    
    Write-Host "`[INFO`] Deleting MSI files for version $Version, architecture $Arch"
    
    # If Arch is empty or "all", search for all architectures
    if ([string]::IsNullOrWhiteSpace($Arch) -or $Arch -eq "all") {
        Write-Host "`[INFO`] Searching for all architectures for version $Version"
        $filesToDelete = @(
            "kamiwaza_installer_${Version}_*.msi",
            "kamiwaza_installer_${Version}_*_build*.msi"
        )
    } else {
        $filesToDelete = @(
            "kamiwaza_installer_${Version}_${Arch}.msi",
            "kamiwaza_installer_${Version}_${Arch}_build*.msi"
        )
    }
    
    $deletedCount = 0
    
    try {
        $awsCmd = "aws"
        if (Test-Path "venv\Scripts\aws.cmd") {
            $awsCmd = "venv\Scripts\aws.cmd"
        }
        
        foreach ($filePattern in $filesToDelete) {
            Write-Host "`[DEBUG`] Searching for files matching: $filePattern"
            
            # List files matching the pattern
            $listCmd = "$awsCmd s3 ls s3://$BucketName/win/ --endpoint-url $EndpointUrl --no-verify-ssl"
            $listResult = Invoke-Expression $listCmd
            
            if ($LASTEXITCODE -eq 0) {
                # Convert wildcard pattern to regex pattern
                $regexPattern = $filePattern.Replace('*', '.*')
                
                foreach ($line in $listResult) {
                    # Extract filename from the S3 ls output format: "2025-09-29 14:46:59   39337882 kamiwaza_installer_0.5.1_x86_64.msi"
                    if ($line -match '\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+\d+\s+(.+)$') {
                        $fileName = $matches[1]
                        
                        if ($fileName -match $regexPattern) {
                            Write-Host "`[INFO`] Deleting: $fileName"
                            
                            $deleteCmd = "$awsCmd s3 rm s3://$BucketName/win/$fileName --endpoint-url $EndpointUrl --no-verify-ssl"
                            Invoke-Expression $deleteCmd
                            
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "`[SUCCESS`] Deleted: $fileName"
                                $deletedCount++
                            } else {
                                Write-Host "`[ERROR`] Failed to delete: $fileName"
                            }
                        }
                    }
                }
            } else {
                Write-Host "`[WARNING`] Could not list files for pattern: $filePattern"
            }
        }
        
        Write-Host "`[INFO`] Deleted $deletedCount files"
        return $deletedCount
    }
    catch {
        Write-Host "`[ERROR`] Delete operation failed: $($_.Exception.Message)"
        return 0
    }
}

# Function to list bucket contents
function List-BucketContents {
    param(
        [string]$BucketName,
        [string]$EndpointUrl
    )
    
    Write-Host "`[INFO`] Listing current contents of s3://$BucketName/win/ directory..."
    
    try {
        $awsCmd = "aws"
        if (Test-Path "venv\Scripts\aws.cmd") {
            $awsCmd = "venv\Scripts\aws.cmd"
        }
        
        Write-Host "`[DEBUG`] Command: $awsCmd s3 ls s3://$BucketName/win/ --endpoint-url $EndpointUrl --no-verify-ssl"
        & $awsCmd s3 ls "s3://$BucketName/win/" --endpoint-url $EndpointUrl --no-verify-ssl
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`[SUCCESS`] Bucket contents listed above"
        } else {
            Write-Host "`[WARNING`] Could not list bucket contents - check AWS configuration (exit code: $LASTEXITCODE)"
        }
    }
    catch {
        Write-Host "`[WARNING`] Could not list bucket contents: $($_.Exception.Message)"
    }
}

# Main script execution
Write-Host "==============================================="
Write-Host "Kamiwaza MSI Management Script (PowerShell)"
Write-Host "==============================================="

# Handle delete operation
if ($Delete) {
    if ([string]::IsNullOrWhiteSpace($Version)) {
        Write-Host "`[ERROR`] Version is required for delete operation"
        Write-Host "Usage: .\upload_msi_to_win.ps1 -Delete -Version `"0.5.0`" -Arch `"x86_64`""
        Write-Host "       .\upload_msi_to_win.ps1 -Delete -Version `"0.5.0`" -Arch `"arm64`" -EnvFile `"custom\env\file.sh`""
        Write-Host "       .\upload_msi_to_win.ps1 -Delete -Version `"0.5.0`" (deletes all architectures)"
        Write-Host ""
        Write-Host "`[DEBUG`] Script completed. Press any key to close..."
        Read-Host
        exit 1
    }
    
    # Set default architecture if not specified
    if ([string]::IsNullOrWhiteSpace($Arch)) {
        $Arch = "all"
        Write-Host "`[INFO`] Delete Mode: Version=$Version, Arch=all (searching all architectures)"
    } else {
        Write-Host "`[INFO`] Delete Mode: Version=$Version, Arch=$Arch"
    }
    Write-Host "`[INFO`] Environment File: $EnvFile"
    Write-Host ""
    
    # Load environment variables
    $envVars = Load-EnvFile -FilePath $EnvFile
    
    # Set AWS environment
    Set-AwsEnvironment -EnvVars $envVars
    
    # Display configuration
    Write-Host ""
    Write-Host "`[INFO`] Delete Configuration:"
    Write-Host "`[INFO`] AWS_ACCESS_KEY_ID: $($env:AWS_ACCESS_KEY_ID)"
    Write-Host "`[INFO`] AWS_SECRET_ACCESS_KEY: $($env:AWS_SECRET_ACCESS_KEY -replace '.', '*')"
    Write-Host "`[INFO`] AWS_ENDPOINT_URL: $($env:AWS_ENDPOINT_URL)"
    Write-Host "`[INFO`] BUCKET_NAME: $($env:BUCKET_NAME)"
    Write-Host ""
    
    # Delete MSI files
    Write-Host "`[INFO`] Deleting MSI files..."
    $deletedCount = Delete-MsiFiles -Version $Version -Arch $Arch -BucketName $env:BUCKET_NAME -EndpointUrl $env:AWS_ENDPOINT_URL
    
    # Show results
    Write-Host ""
    Write-Host "==============================================="
    Write-Host "DELETE RESULTS"
    Write-Host "==============================================="
    
    if ($deletedCount -gt 0) {
        if ($Arch -eq "all") {
            Write-Host "`[SUCCESS`] Deleted $deletedCount MSI files for version $Version (all architectures)"
        } else {
            Write-Host "`[SUCCESS`] Deleted $deletedCount MSI files for version $Version ($Arch)"
        }
    } else {
        if ($Arch -eq "all") {
            Write-Host "`[WARNING`] No MSI files found for version $Version (any architecture)"
        } else {
            Write-Host "`[WARNING`] No MSI files found for version $Version ($Arch)"
        }
    }
    
    Write-Host "==============================================="
    
    # List current bucket contents
    Write-Host ""
    List-BucketContents -BucketName $env:BUCKET_NAME -EndpointUrl $env:AWS_ENDPOINT_URL
    
    Write-Host ""
    Write-Host "`[DEBUG`] Script completed. Press any key to close..."
    Read-Host
    exit 0
}

# Handle upload operation
# Auto-detect MSI file if not provided but EnvFile looks like an MSI file
if ([string]::IsNullOrWhiteSpace($MsiFilePath)) {
    if (-not [string]::IsNullOrWhiteSpace($EnvFile) -and $EnvFile.EndsWith('.msi')) {
        Write-Host "`[INFO`] Auto-detected MSI file from EnvFile parameter: $EnvFile"
        $MsiFilePath = $EnvFile
        # Reset EnvFile to default since it was actually the MSI file
        $EnvFile = ""
    } else {
        Write-Host "`[ERROR`] Please provide an MSI file path as an argument or use -Delete flag"
        Write-Host "Upload Usage: .\upload_msi_to_win.ps1 -MsiFilePath `"path\to\your\installer.msi`""
        Write-Host "             .\upload_msi_to_win.ps1 -MsiFilePath `"path\to\your\installer.msi`" -EnvFile `"custom\env\file.sh`""
        Write-Host "Delete Usage: .\upload_msi_to_win.ps1 -Delete -Version `"0.5.0`" -Arch `"x86_64`""
        Write-Host "             .\upload_msi_to_win.ps1 -Delete -Version `"0.5.0`" -Arch `"arm64`" -EnvFile `"custom\env\file.sh`""
        Write-Host "             .\upload_msi_to_win.ps1 -Delete -Version `"0.5.0`" (deletes all architectures)"
        Write-Host ""
        Write-Host "`[DEBUG`] Script completed. Press any key to close..."
        Read-Host
        exit 1
    }
}

# Validate that the MSI file exists
if (-not (Test-Path $MsiFilePath)) {
    Write-Host "`[ERROR`] MSI file not found: $MsiFilePath"
    Write-Host "Please check the file path and try again."
    Write-Host ""
    Write-Host "`[DEBUG`] Script completed. Press any key to close..."
    Read-Host
    exit 1
}

Write-Host "`[INFO`] MSI File: $MsiFilePath"
Write-Host "`[INFO`] Environment File: $EnvFile"
Write-Host ""

# Load environment variables
$envVars = Load-EnvFile -FilePath $EnvFile

# Set AWS environment
Set-AwsEnvironment -EnvVars $envVars

# Display configuration
Write-Host ""
Write-Host "`[INFO`] Upload Configuration:"
Write-Host "`[INFO`] AWS_ACCESS_KEY_ID: $($env:AWS_ACCESS_KEY_ID)"
Write-Host "`[INFO`] AWS_SECRET_ACCESS_KEY: $($env:AWS_SECRET_ACCESS_KEY -replace '.', '*')"
Write-Host "`[INFO`] AWS_ENDPOINT_URL: $($env:AWS_ENDPOINT_URL)"
Write-Host "`[INFO`] BUCKET_NAME: $($env:BUCKET_NAME)"
Write-Host ""

# Prepare MSI file for upload with new naming convention
Write-Host "`[INFO`] Preparing MSI file for upload..."

# Extract version and architecture from MSI filename if not provided
if ([string]::IsNullOrWhiteSpace($Version) -or [string]::IsNullOrWhiteSpace($Arch)) {
    Write-Host "`[INFO`] Extracting version and architecture from MSI filename..."
    
    $msiFileName = Split-Path $MsiFilePath -Leaf
    Write-Host "`[DEBUG`] MSI filename: $msiFileName"
    
    # Parse filename pattern: kamiwaza_installer_VERSION_ARCH.msi
    if ($msiFileName -match 'kamiwaza_installer_([^_]+)_([^.]+)\.msi$') {
        $Version = $matches[1]
        $Arch = $matches[2]
        Write-Host "`[SUCCESS`] Extracted from filename - Version: $Version, Arch: $Arch"
    } else {
        Write-Host "`[WARNING`] Could not parse version/arch from filename, trying config.yaml..."
        try {
            $configContent = Get-Content "config.yaml" -ErrorAction Stop
            foreach ($line in $configContent) {
                if ($line -match '^kamiwaza_version:\s*(.+)$') {
                    $Version = $matches[1].Trim()
                }
                if ($line -match '^arch:\s*(.+?)(?:\s+#|$)') {
                    $Arch = $matches[1].Trim()
                }
            }
            Write-Host "`[INFO`] Using config.yaml values - Version: $Version, Arch: $Arch"
        }
        catch {
            Write-Host "`[ERROR`] Could not read config.yaml and filename parsing failed"
            Write-Host "`[ERROR`] Please provide version and architecture explicitly or use proper filename format"
            Write-Host "`[ERROR`] Expected format: kamiwaza_installer_VERSION_ARCH.msi"
            Write-Host "`[ERROR`] Example: kamiwaza_installer_0.5.1_x86_64.msi"
            Write-Host ""
            Write-Host "`[DEBUG`] Script completed. Press any key to close..."
            Read-Host
            exit 1
        }
    }
}

# Clean up values
$Version = $Version.Trim()
$Arch = $Arch.Trim()

# Create new naming convention: kamiwaza_installer_version_arch.msi
$uploadMsiName = "kamiwaza_installer_${Version}_${Arch}.msi"
$tempMsiPath = Join-Path $PWD $uploadMsiName

Write-Host "`[INFO`] Using naming convention: $uploadMsiName"

try {
    Copy-Item $MsiFilePath $tempMsiPath -Force
    Write-Host "`[SUCCESS`] MSI file prepared for upload: $uploadMsiName"
}
catch {
    Write-Host "`[ERROR`] Failed to copy MSI file for upload: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "`[DEBUG`] Script completed. Press any key to close..."
    Read-Host
    exit 1
}

# Upload the MSI file
Write-Host ""
Write-Host "`[INFO`] Uploading MSI to R2 Cloudflare..."
$uploadSuccess = Upload-MsiFile -SourceFile $tempMsiPath -TargetName $uploadMsiName -BucketName $env:BUCKET_NAME -EndpointUrl $env:AWS_ENDPOINT_URL

# Show results
Write-Host ""
Write-Host "==============================================="
Write-Host "UPLOAD RESULTS"
Write-Host "==============================================="

if ($uploadSuccess) {
    $genericMsiUrl = "https://packages.kamiwaza.ai/win/$uploadMsiName"
    Write-Host "`[SUCCESS`] MSI uploaded successfully!"
    Write-Host "`[SUCCESS`] MSI URL: $genericMsiUrl"
    Write-Host ""
    Write-Host "`[INFO`] Copy this URL for distribution:"
    Write-Host "       $genericMsiUrl"
    Write-Host ""
    Write-Host "`[INFO`] File naming convention: kamiwaza_installer_version_arch.msi"
    Write-Host "`[INFO`] Example: kamiwaza_installer_0.5.0_x86_64.msi"
} else {
    Write-Host "`[ERROR`] Upload failed!"
    Write-Host "`[INFO`] MSI file is available locally: $uploadMsiName"
    Write-Host "`[INFO`] Please check your AWS configuration and try again."
    Write-Host "`[INFO`] Make sure your environment file contains valid AWS credentials"
}

Write-Host "==============================================="

# List current bucket contents
Write-Host ""
List-BucketContents -BucketName $env:BUCKET_NAME -EndpointUrl $env:AWS_ENDPOINT_URL

Write-Host "==============================================="

# Clean up the copied MSI file
Write-Host ""
Write-Host "`[INFO`] Cleaning up temporary files..."
if (Test-Path $tempMsiPath) {
    try {
        Remove-Item $tempMsiPath -Force
        Write-Host "`[SUCCESS`] Temporary MSI file cleaned up"
    }
    catch {
        Write-Host "`[WARNING`] Could not clean up temporary MSI file: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "`[DEBUG`] Script completed. Press any key to close..."
Read-Host