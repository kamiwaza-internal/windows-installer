# Test script to verify SSL fixes for AWS wrapper
param(
    [string]$EndpointUrl = "https://a8269aa1c3e707a1ce89dd67bdef4a0f.r2.cloudflarestorage.com"
)

Write-Host "=== Testing SSL Fixes for AWS Upload ==="
Write-Host "Endpoint URL: $EndpointUrl"
Write-Host ""

# Set the same SSL configurations as in the wrapper
$env:PYTHONHTTPSVERIFY = "0"
$env:AWS_CLI_SSL_NO_VERIFY = "true"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

Write-Host "1. Testing SSL configuration..."
try {
    $testUrl = "https://pub-3feaeada14ef4a368ea38717abd3cf7e.r2.dev/"
    $response = Invoke-WebRequest -Uri $testUrl -Method Head -TimeoutSec 10 -UseBasicParsing
    Write-Host "[OK] SSL configuration working - can connect to R2 endpoint"
    Write-Host "    Response status: $($response.StatusCode)"
} catch {
    Write-Host "[ERROR] SSL configuration test failed: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "2. Testing AWS CLI SSL bypass..."
if (Test-Path "venv\Scripts\aws.cmd") {
    try {
        Write-Host "Testing AWS CLI with SSL bypass..."
        $result = & "venv\Scripts\aws.cmd" s3 ls "s3://k-ubuntu/" --endpoint-url $EndpointUrl --no-verify-ssl --max-items 1 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] AWS CLI SSL bypass working"
            Write-Host "    Sample output: $($result | Select-Object -First 1)"
        } else {
            Write-Host "[ERROR] AWS CLI SSL bypass failed"
            Write-Host "    Error output: $result"
        }
    } catch {
        Write-Host "[ERROR] AWS CLI test exception: $($_.Exception.Message)"
    }
} else {
    Write-Host "[WARN] AWS CLI not found at venv\Scripts\aws.cmd"
    Write-Host "       This test requires the AWS CLI virtual environment to be set up"
}

Write-Host ""
Write-Host "3. Testing wrapper scripts..."

# Test regular wrapper
Write-Host "Testing aws_wrapper.ps1..."
try {
    $wrapperResult = & powershell -ExecutionPolicy Bypass -File "aws_wrapper.ps1" -Operation "find-build" -Version "0.5.0" -Arch "amd64" -StartBuild 999 -EndpointUrl $EndpointUrl 2>&1
    if ($wrapperResult -match "FINAL_BUILD_NUMBER=") {
        Write-Host "[OK] Regular wrapper working"
    } else {
        Write-Host "[WARN] Regular wrapper may have issues"
        Write-Host "    Output: $wrapperResult"
    }
} catch {
    Write-Host "[ERROR] Regular wrapper test failed: $($_.Exception.Message)"
}

# Test fallback wrapper
Write-Host "Testing aws_wrapper_fallback.ps1..."
try {
    $fallbackResult = & powershell -ExecutionPolicy Bypass -File "aws_wrapper_fallback.ps1" -Operation "find-build" -Version "0.5.0" -Arch "amd64" -StartBuild 999 -EndpointUrl $EndpointUrl 2>&1
    if ($fallbackResult -match "FINAL_BUILD_NUMBER=") {
        Write-Host "[OK] Fallback wrapper working"
    } else {
        Write-Host "[WARN] Fallback wrapper may have issues"
        Write-Host "    Output: $fallbackResult"
    }
} catch {
    Write-Host "[ERROR] Fallback wrapper test failed: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "=== Test Summary ==="
Write-Host "If all tests show [OK], the SSL fix should resolve upload issues."
Write-Host "If tests show [ERROR] or [WARN], additional troubleshooting may be needed."
Write-Host ""
Write-Host "To test with actual build:"
Write-Host "  build.bat --no-upload   (to test build without upload)"
Write-Host "  build.bat               (to test build with upload)"