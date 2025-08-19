# Kamiwaza Installer Testing Suite

This testing suite provides comprehensive validation of the Kamiwaza installer configuration without actually running the installation. It's designed to be repeatable and can catch configuration issues before deployment.

## Overview

The testing suite validates:
- **WSL Integration**: Memory configuration, cleanup scripts, and WSL-specific components
- **GPU Scripts**: Detection and setup scripts for NVIDIA, Intel Arc, and integrated GPUs
- **File Placements**: All required files are present and properly referenced
- **Execution Sequence**: Custom actions are properly sequenced during installation
- **Registry Entries**: Registry cleanup and autostart configuration
- **Cleanup Actions**: Proper uninstall cleanup for files, folders, and ports

## Test Files

### 1. `test_installer_simple.py` - Simple Test Runner
- **Purpose**: Quick validation of essential installer components
- **Scope**: Basic file existence, WiX parsing, and core functionality
- **Best for**: Daily development testing and quick validation

### 2. `test_installer_components.py` - Component Test Suite
- **Purpose**: Detailed testing of specific installer components
- **Scope**: WSL integration, GPU scripts, file placements, execution sequence
- **Best for**: Comprehensive component validation and debugging

### 3. `test_installer_validation.py` - Full Validation Suite
- **Purpose**: Complete installer configuration validation
- **Scope**: All aspects of the installer including UI, properties, and custom actions
- **Best for**: Final validation before release and deep debugging

## Running the Tests

### Option 1: PowerShell (Recommended)
```powershell
# Run all available tests
.\test-installer.ps1

# Run with verbose output
.\test-installer.ps1 -Verbose

# Export results to JSON
.\test-installer.ps1 -ExportResults -OutputFile "my_results.json"
```

### Option 2: Batch File
```cmd
# Run tests using batch file
test-installer.bat
```

### Option 3: Direct Python Execution
```bash
# Run simple tests
python test_installer_simple.py

# Run component tests
python test_installer_components.py

# Run full validation
python test_installer_validation.py
```

## What Gets Tested

### WSL Integration
- ✅ WSL memory configuration script (`configure_wsl_memory.ps1`)
- ✅ WSL cleanup scripts (`cleanup_wsl_kamiwaza.ps1`, `cleanup_installs.bat`)
- ✅ WSL memory property configuration (default: 14GB)
- ✅ WSL-specific custom actions

### GPU Scripts
- ✅ GPU detection scripts (`detect_gpu.ps1`, `detect_gpu_cmd.bat`)
- ✅ NVIDIA GPU setup (`setup_nvidia_gpu.sh`)
- ✅ Intel Arc GPU setup (`setup_intel_arc_gpu.sh`)
- ✅ Intel integrated GPU setup (`setup_intel_integrated_gpu.sh`)
- ✅ GPU detection custom actions

### File Placements
- ✅ Main installation directory structure
- ✅ Python runtime directory configuration
- ✅ All required script files present
- ✅ Source file existence validation
- ✅ Component file references

### Execution Sequence
- ✅ Custom action definitions
- ✅ Install execution sequence
- ✅ Critical action ordering
- ✅ Action dependencies

### Registry and Cleanup
- ✅ Registry entry configuration
- ✅ Cleanup on uninstall
- ✅ Autostart registry setup
- ✅ File and folder removal actions
- ✅ Port reservation and release

## Test Results

### Success Indicators
- 🎉 **ALL TESTS PASSED**: Installer configuration is valid
- ✅ **Individual test passed**: Component is properly configured
- ℹ️ **Info messages**: Additional validation information

### Warning Indicators
- ⚠️ **Warnings**: Non-critical issues that should be reviewed
- 🟡 **Yellow text**: Items that exist but may need attention

### Error Indicators
- ❌ **Errors**: Critical issues that must be fixed
- 🔴 **Red text**: Failed validations that prevent proper operation

## Exit Codes

- **0**: All tests passed successfully
- **1**: Some tests failed (critical issues)
- **2**: Tests passed with warnings

## Customizing Tests

### Adding New Test Cases
1. Identify the component to test
2. Add test method to appropriate test class
3. Update the main test runner to include your test
4. Ensure proper error handling and reporting

### Example Test Method
```python
def test_my_component(self):
    """Test my custom component."""
    logger.info("Testing my component...")
    
    # Your test logic here
    if component_exists:
        self.test_results['my_component']['passed'].append("Component found")
    else:
        self.test_results['my_component']['failed'].append("Component missing")
    
    # Set status
    if self.test_results['my_component']['failed']:
        self.test_results['my_component']['status'] = 'FAILED'
    else:
        self.test_results['my_component']['status'] = 'PASSED'
```

## Troubleshooting

### Common Issues

#### Python Not Found
```bash
# Install Python from https://www.python.org/downloads/
# Ensure Python is in your PATH
python --version
```

#### Missing Test Files
- Ensure all test scripts are in the same directory
- Check file permissions and execution rights
- Verify Python dependencies are installed

#### WiX File Parsing Errors
- Validate XML syntax in `installer.wxs`
- Check for malformed XML elements
- Ensure proper namespace declarations

### Debug Mode
Run tests with verbose output to see detailed execution:
```powershell
.\test-installer.ps1 -Verbose
```

## Integration with CI/CD

### GitHub Actions Example
```yaml
name: Installer Validation
on: [push, pull_request]
jobs:
  validate-installer:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v2
    - name: Set up Python
      uses: actions/setup-python@v2
      with:
        python-version: '3.9'
    - name: Run Installer Tests
      run: python test_installer_simple.py
```

### Azure DevOps Example
```yaml
- task: UsePythonVersion@0
  inputs:
    versionSpec: '3.9'
- script: python test_installer_simple.py
  displayName: 'Validate Installer Configuration'
```

## Best Practices

1. **Run tests frequently**: Test after any installer configuration changes
2. **Fix issues immediately**: Address failed tests before proceeding
3. **Review warnings**: Warnings may indicate potential issues
4. **Document customizations**: Keep test modifications documented
5. **Version control**: Include test scripts in your repository

## Support

For issues with the testing suite:
1. Check the test output for specific error messages
2. Verify all required files are present
3. Ensure Python environment is properly configured
4. Review the WiX file for syntax errors

## Contributing

To improve the testing suite:
1. Identify areas that need better coverage
2. Add comprehensive test cases
3. Ensure backward compatibility
4. Update documentation for new features 