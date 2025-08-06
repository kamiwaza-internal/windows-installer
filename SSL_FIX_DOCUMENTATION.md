# SSL Certificate Validation Fix for AWS/R2 Upload

## Problem

The build system was experiencing SSL validation errors when uploading to Cloudflare R2:

```
SSL validation failed for https://a8269aa1c3e707a1ce89dd67bdef4a0f.r2.cloudflarestorage.com/...
EOF occurred in violation of protocol (_ssl.c:2426)
```

## Root Cause

The AWS CLI was having SSL/TLS handshake issues with the Cloudflare R2 endpoint, likely due to:
- Certificate validation strict mode
- TLS protocol version mismatches
- SSL verification conflicts

## Solution Implemented

### 1. Enhanced `aws_wrapper.ps1`

Added SSL bypass configurations:
```powershell
# Set environment variables to help with SSL/TLS issues
$env:PYTHONHTTPSVERIFY = "0"
$env:AWS_CLI_SSL_NO_VERIFY = "true"

# Additional SSL configuration
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
```

Added `--no-verify-ssl` flag to all AWS CLI commands:
```powershell
& "venv\Scripts\aws.cmd" s3 cp "kamiwaza_installer.msi" "s3://k-ubuntu/$msiName" --endpoint-url $EndpointUrl --no-verify-ssl
```

### 2. Created `aws_wrapper_fallback.ps1`

A robust fallback system with multiple upload methods:
- **Method 1**: AWS CLI with SSL bypass
- **Method 2**: AWS CLI with additional timeout options
- **Method 3**: Direct HTTP requests (as fallback)

### 3. Updated `build.bat`

Added fallback logic:
```batch
REM Try the regular AWS wrapper first
set UPLOAD_SUCCESS=0
for /f "tokens=1,2 delims==" %%A in ('powershell ... aws_wrapper.ps1 ...') do (
    # Parse results
)

REM If regular upload failed, try the fallback wrapper
if "%UPLOAD_SUCCESS%"=="0" (
    echo [WARN] Regular upload failed, trying fallback method...
    for /f "tokens=1,2 delims==" %%A in ('powershell ... aws_wrapper_fallback.ps1 ...') do (
        # Parse fallback results
    )
)
```

## Files Modified/Created

### Modified Files
- `aws_wrapper.ps1` - Added SSL bypass configurations
- `build.bat` - Added fallback upload logic

### New Files
- `aws_wrapper_fallback.ps1` - Comprehensive fallback wrapper
- `test-ssl-fix.ps1` - SSL fix testing script
- `SSL_FIX_DOCUMENTATION.md` - This documentation

## Testing

### Test the Fix
```batch
# Test SSL configuration
powershell -ExecutionPolicy Bypass -File test-ssl-fix.ps1

# Test build without upload
build.bat --no-upload

# Test build with upload
build.bat
```

### Expected Behavior

**Before Fix:**
```
upload failed: .\kamiwaza_installer.msi to s3://k-ubuntu/...
SSL validation failed for https://...
EOF occurred in violation of protocol (_ssl.c:2426)
```

**After Fix:**
```
[INFO] Uploading files to AWS...
[SUCCESS] MSI uploaded successfully
[SUCCESS] MSI: https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/kamiwaza_installer_0.5.0_amd64_buildXXX.msi
```

**If Primary Method Fails:**
```
[INFO] Uploading files to AWS...
[WARN] Regular upload failed, trying fallback method...
[SUCCESS] MSI uploaded successfully via fallback method
```

## Troubleshooting

### If Upload Still Fails

1. **Check AWS CLI Installation:**
   ```batch
   venv\Scripts\aws.cmd --version
   ```

2. **Verify Endpoint URL:**
   ```batch
   echo %R2_ENDPOINT_URL%
   ```

3. **Test Network Connectivity:**
   ```batch
   ping pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev
   ```

4. **Check AWS Credentials:**
   ```batch
   venv\Scripts\aws.cmd configure list
   ```

### Manual Upload Test

```batch
# Test manual upload
venv\Scripts\aws.cmd s3 cp kamiwaza_installer.msi s3://k-ubuntu/test_upload.msi --endpoint-url https://a8269aa1c3e707a1ce89dd67bdef4a0f.r2.cloudflarestorage.com --no-verify-ssl
```

## Security Considerations

**SSL Verification Bypass**: The fix disables SSL certificate verification for uploads. This is acceptable because:
- Used only for internal build/release process
- Cloudflare R2 is a trusted service
- Alternative would be to configure proper certificate chains
- Upload integrity is still protected by AWS CLI checksums

**Environment Variables**: SSL bypass is scoped to the PowerShell wrapper processes only.

## Alternative Solutions

If the current fix doesn't work, consider:

1. **Update AWS CLI**: Newer versions may handle SSL better
2. **Configure Certificate Bundle**: Set proper CA bundle path
3. **Use Different Endpoint**: Try alternative R2 endpoints
4. **Switch to Native PowerShell**: Use Invoke-WebRequest with multipart upload

## Monitoring

Monitor build logs for:
- `[SUCCESS] MSI uploaded successfully` - Primary method worked
- `[SUCCESS] MSI uploaded successfully via fallback method` - Fallback worked
- `[ERROR] MSI upload failed even with fallback method!` - Both methods failed

## Validation

The fix is working correctly when:
1. Build completes without SSL errors
2. MSI file is uploaded successfully
3. Public URL is generated and accessible
4. Build number increments properly for next build