# Pre-Push Git Hook for Kamiwaza Installer

## Overview

This repository includes a **pre-push git hook** that automatically runs the testing suite before allowing any code to be pushed. This ensures code quality and catches issues early in the development process.

## What It Does

The pre-push hook:

1. **Automatically runs tests** before every `git push`
2. **Blocks pushes** if tests fail
3. **Ensures installer quality** by validating:
   - WiX file configuration
   - Required file presence
   - WSL integration setup
   - GPU script availability
   - Execution sequence validation
   - Registry and cleanup configuration

## How It Works

### Automatic Execution
- **Every time** you run `git push`, the hook runs automatically
- **No manual intervention** required - it's completely transparent
- **Immediate feedback** on test results

### Test Suite
The hook runs `test_installer_simple_fixed.py` which validates:
- ✅ WiX installer file parsing
- ✅ Required script files existence
- ✅ WSL integration components
- ✅ GPU detection and setup scripts
- ✅ Custom action execution sequence
- ✅ Registry cleanup configuration

### Push Control
- **Tests PASS**: Push proceeds normally
- **Tests FAIL**: Push is blocked with detailed error information

## Installation

The hook is already installed in this repository at `.git/hooks/pre-push`.

### Manual Installation (if needed)
```bash
# Copy the hook to your git hooks directory
cp .git/hooks/pre-push .git/hooks/
chmod +x .git/hooks/pre-push

# Or on Windows, ensure the batch file is executable
icacls .git/hooks/pre-push.bat /grant Everyone:F
```

## Usage

### Normal Development Flow
```bash
# Make your changes
git add .
git commit -m "Your commit message"

# Push (hook runs automatically)
git push origin main
```

### What You'll See

#### Successful Tests (Push Allowed)
```
==========================================
KAMIWAZA INSTALLER PRE-PUSH TESTING
==========================================
Running test suite before push...

Current branch: main
WARNING: Pushing to main branch - running FULL test suite

Python found: Python 3.10.11
Test files verified

Running main test suite...
========================================
Kamiwaza Installer Simple Test Runner
========================================
... (test output) ...
=================================================
TEST SUMMARY: 6/6 tests passed
[SUCCESS] ALL TESTS PASSED - Installer configuration is valid!

==========================================
✅ ALL TESTS PASSED - Push allowed!
Installer configuration is valid and ready for deployment.

Test Summary:
- WiX file validation: PASSED
- Required files check: PASSED
- WSL integration: PASSED
- GPU scripts: PASSED
- Execution sequence: PASSED
- Registry & cleanup: PASSED

Proceeding with push...
```

#### Failed Tests (Push Blocked)
```
==========================================
KAMIWAZA INSTALLER PRE-PUSH TESTING
==========================================
Running test suite before push...

Current branch: feature-branch

Python found: Python 3.10.11
Test files verified

Running main test suite...
========================================
Kamiwaza Installer Simple Test Runner
========================================
... (test output with failures) ...

==========================================
❌ TESTS FAILED - Push blocked!

The installer has validation issues that must be fixed before pushing:
1. Review the test output above
2. Fix any failed tests
3. Re-run tests: python test_installer_simple_fixed.py
4. Try pushing again

Push blocked to maintain code quality.
```

## Troubleshooting

### Hook Not Running
```bash
# Check if hook exists and is executable
ls -la .git/hooks/pre-push*

# On Windows, check permissions
icacls .git/hooks/pre-push*
```

### Python Not Found
```bash
# Ensure Python is in PATH
python --version

# Or use full path in hook
# Edit .git/hooks/pre-push.bat and change:
# python test_installer_simple_fixed.py
# to:
# "C:\Path\To\Python\python.exe" test_installer_simple_fixed.py
```

### Test Files Missing
```bash
# Ensure test files are in repository root
ls -la test_installer_simple_fixed.py

# If missing, restore from git
git checkout test_installer_simple_fixed.py
```

## Bypassing the Hook (Emergency Only)

⚠️ **WARNING: Only use in emergencies!**

```bash
# Skip pre-push hook (not recommended)
git push --no-verify origin main

# Or temporarily disable
mv .git/hooks/pre-push .git/hooks/pre-push.disabled
git push origin main
mv .git/hooks/pre-push.disabled .git/hooks/pre-push
```

## Customization

### Adding More Tests
Edit `.git/hooks/pre-push.bat` and add additional test commands:

```batch
REM Run additional tests
python test_installer_components.py
if %errorlevel% neq 0 (
    echo Component tests failed!
    exit /b 1
)

python test_installer_validation.py
if %errorlevel% neq 0 (
    echo Validation tests failed!
    exit /b 1
)
```

### Changing Test File
Edit the hook to use a different test file:

```batch
REM Change from:
python test_installer_simple_fixed.py

REM To:
python your_custom_test_file.py
```

### Adding Notifications
Add Slack/Teams notifications for test failures:

```batch
REM After test failure
echo Sending notification...
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Tests failed on push to %currentBranch%"}' \
  https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

## Benefits

1. **Quality Assurance**: No broken code gets pushed
2. **Early Detection**: Issues caught before they reach production
3. **Team Confidence**: Everyone knows the codebase is tested
4. **Automated Validation**: No manual testing steps forgotten
5. **Documentation**: Test results provide immediate feedback

## Best Practices

1. **Always run tests locally** before committing
2. **Fix test failures immediately** - don't let them accumulate
3. **Keep test suite fast** - hooks should complete quickly
4. **Use descriptive commit messages** - helps with debugging
5. **Regular test maintenance** - keep tests up to date with code

## Support

If you encounter issues with the pre-push hook:

1. Check this README for troubleshooting steps
2. Review the test output for specific error messages
3. Ensure all dependencies are installed
4. Verify file permissions and paths
5. Check git configuration and hook installation

---

**Remember**: The pre-push hook is your friend! It ensures that every push maintains the high quality standards of the Kamiwaza installer. 