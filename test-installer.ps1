# Kamiwaza Installer Validation Test Runner
# This script runs comprehensive installer validation tests without installing anything

param(
    [switch]$Verbose,
    [switch]$ExportResults,
    [string]$OutputFile = "installer_test_results.json"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Kamiwaza Installer Validation Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Python is available
try {
    $pythonVersion = python --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Python found: $pythonVersion" -ForegroundColor Green
    } else {
        throw "Python not available"
    }
} catch {
            Write-Host "[FAIL] ERROR: Python is not available. Please install Python and try again." -ForegroundColor Red
    Write-Host "You can download Python from: https://www.python.org/downloads/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Running installer validation tests..." -ForegroundColor Yellow
Write-Host ""

# Check if test files exist
$testFiles = @(
    "test_installer_simple_fixed.py",
    "test_installer_components.py",
    "test_installer_validation.py"
)

$availableTests = @()
foreach ($testFile in $testFiles) {
    if (Test-Path $testFile) {
        $availableTests += $testFile
        Write-Host "[OK] Found test file: $testFile" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Test file not found: $testFile" -ForegroundColor Yellow
    }
}

if ($availableTests.Count -eq 0) {
            Write-Host "[FAIL] No test files found. Please ensure test scripts are in the current directory." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Available tests: $($availableTests.Count)" -ForegroundColor Cyan

# Run the simple test runner first (most comprehensive)
Write-Host ""
Write-Host "Running simple test runner..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Gray

try {
    $result = python test_installer_simple_fixed.py 2>&1
    $exitCode = $LASTEXITCODE
    
    # Display results
    Write-Host $result
    
    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host "[SUCCESS] Simple test runner completed successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "[WARN] Simple test runner completed with issues (exit code: $exitCode)" -ForegroundColor Yellow
    }
    
} catch {
            Write-Host "[FAIL] Failed to run simple test runner: $_" -ForegroundColor Red
    $exitCode = 1
}

# Run component tests if available
if (Test-Path "test_installer_components.py") {
    Write-Host ""
    Write-Host "Running component tests..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Gray
    
    try {
        $componentResult = python test_installer_components.py 2>&1
        $componentExitCode = $LASTEXITCODE
        
        Write-Host $componentResult
        
        if ($componentExitCode -eq 0) {
            Write-Host "[SUCCESS] Component tests completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "[WARN] Component tests completed with issues (exit code: $componentExitCode)" -ForegroundColor Yellow
        }
        
        # Update overall exit code if component tests failed
        if ($componentExitCode -ne 0) {
            $exitCode = $componentExitCode
        }
        
    } catch {
        Write-Host "[FAIL] Failed to run component tests: $_" -ForegroundColor Red
        $exitCode = 1
    }
}

# Run comprehensive validation if available
if (Test-Path "test_installer_validation.py") {
    Write-Host ""
    Write-Host "Running comprehensive validation..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Gray
    
    try {
        $validationResult = python test_installer_validation.py 2>&1
        $validationExitCode = $LASTEXITCODE
        
        Write-Host $validationResult
        
        if ($validationExitCode -eq 0) {
            Write-Host "[SUCCESS] Comprehensive validation completed successfully!" -ForegroundColor Green
        } else {
            Write-Host "[WARN] Comprehensive validation completed with issues (exit code: $validationExitCode)" -ForegroundColor Yellow
        }
        
        # Update overall exit code if validation failed
        if ($validationExitCode -ne 0) {
            $exitCode = $validationExitCode
        }
        
    } catch {
        Write-Host "[FAIL] Failed to run comprehensive validation: $_" -ForegroundColor Red
        $exitCode = 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test execution completed" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Summary
if ($exitCode -eq 0) {
            Write-Host "[SUCCESS] ALL TESTS PASSED - Installer configuration is valid!" -ForegroundColor Green
} else {
            Write-Host "[WARN] SOME TESTS FAILED - Review installer configuration" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Test files run: $($availableTests.Count)" -ForegroundColor Cyan
Write-Host "Overall result: $exitCode" -ForegroundColor Cyan

if ($ExportResults) {
    Write-Host ""
    Write-Host "Exporting results to: $OutputFile" -ForegroundColor Yellow
    # This would export the test results to JSON if implemented
}

Write-Host ""
Write-Host "Check the output above for detailed test results." -ForegroundColor White
Write-Host "Review any failed tests and fix the installer configuration." -ForegroundColor White

Read-Host "Press Enter to exit"
exit $exitCode 