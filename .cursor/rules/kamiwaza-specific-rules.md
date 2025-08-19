# Kamiwaza Installer Project - Specific Rules

## 🎯 Project Context
This is a **Windows MSI installer** for Kamiwaza, a WSL-based platform with GPU acceleration support. The installer uses WiX, CustomActions, and batch file integration.

## 🚨 Project-Specific Critical Rules

### WiX/MSI Compilation
- **NEVER ignore** WiX compiler errors - they WILL cause installation failures
- **ALWAYS test** WiX compilation after ANY changes to `installer.wxs`
- **NEVER assume** CustomActions work just because they look correct
- **ALWAYS verify** file paths and registry entries are correct

### CustomAction Syntax Rules
- **NEVER mix** `FileKey` and `Directory` attributes in CustomActions
- **ALWAYS use** `FileKey` for file-based CustomActions
- **NEVER use** `Directory` when `FileKey` is specified
- **ALWAYS test** CustomAction execution after changes

### Batch File Integration
- **ALWAYS add** `pause >nul` to batch files for debugging visibility
- **NEVER use** `exit /b` without user interaction first
- **ALWAYS test** batch files manually before including in MSI
- **NEVER assume** paths are correct without verification

## 🔧 Common Issues & Solutions

### WiX Compilation Errors

#### CNDL0022: CustomAction/@Directory attribute conflict
**Problem**: Mixing `FileKey` and `Directory` attributes
**Solution**: Remove `Directory` attribute when using `FileKey`

#### CNDL0005: Unexpected RegistryValue element
**Problem**: RegistryValue in wrong location or format
**Solution**: Use CustomActions for registry manipulation

#### CNDL1077: Property reference warnings
**Problem**: Property values that look like references
**Solution**: Use CustomActions with batch files for complex operations

### Path Handling Issues

#### Missing Backslashes in Paths
**Problem**: `C:\path\file` vs `C:\pathfile`
**Solution**: Always ensure proper path concatenation in batch files

#### File Not Found Errors
**Problem**: Files not deployed or wrong paths
**Solution**: Verify file inclusion in MSI and test paths manually

### CustomAction Execution Failures

#### Return Code 1 (Failure)
**Problem**: CustomAction failed to execute
**Solution**: Test batch file manually, check file paths, verify parameters

#### Missing Files
**Problem**: CustomAction can't find required files
**Solution**: Verify file deployment, check working directory, test manually

## 🧪 Project Testing Requirements

### Before Any "Fix" Declaration
1. **WiX Compilation Test**
   ```bash
   ./build.bat
   # Verify: "WiX compilation completed" message
   ```

2. **MSI Build Test**
   ```bash
   # Verify: "MSI installer built successfully" message
   ```

3. **Installation Test**
   ```bash
   msiexec /i kamiwaza_installer.msi /l*v test_install.log
   # Verify: All CustomActions execute successfully
   ```

4. **Functionality Test**
   - Test all batch files manually
   - Verify WSL integration
   - Test GPU detection
   - Verify registry entries

5. **Uninstall Test**
   ```bash
   msiexec /x kamiwaza_installer.msi /l*v test_uninstall.log
   # Verify: Clean removal
   ```

### Testing Checklist for This Project
- [ ] WiX compilation succeeds
- [ ] MSI builds without errors
- [ ] All files are included in MSI
- [ ] CustomActions execute successfully
- [ ] Batch files run without errors
- [ ] WSL integration works
- [ ] GPU detection functions
- [ ] Registry entries created correctly
- [ ] Uninstall process works
- [ ] No leftover files or registry entries

## 🚫 Project-Specific "Never Do" Rules

### Never Do These in This Project
- **NEVER claim** WiX compilation errors are "just warnings"
- **NEVER assume** CustomActions work without testing
- **NEVER skip** testing batch file execution
- **NEVER ignore** path concatenation issues
- **NEVER assume** files are deployed correctly
- **NEVER skip** testing the complete installation flow
- **NEVER assume** WSL integration works without verification

### Common Project Mistakes
- Making WiX changes without testing compilation
- Assuming batch files work because they look correct
- Not testing CustomAction execution
- Ignoring path-related errors
- Skipping integration testing
- Not testing on clean systems

## [SUCCESS] Project-Specific "Always Do" Rules

### Always Do These in This Project
- **ALWAYS test** WiX compilation after changes
- **ALWAYS verify** CustomAction execution
- **ALWAYS test** batch files manually
- **ALWAYS verify** file deployment
- **ALWAYS test** complete installation flow
- **ALWAYS verify** WSL integration
- **ALWAYS test** GPU detection
- **ALWAYS verify** registry creation
- **ALWAYS test** uninstall process

## 🔍 Project Debugging Process

### When WiX Compilation Fails
1. **STOP** and don't make more changes
2. **READ** the error message carefully
3. **IDENTIFY** the specific issue (syntax, attribute conflict, etc.)
4. **FIX** the specific issue
5. **TEST** compilation again
6. **REPEAT** until compilation succeeds

### When CustomActions Fail
1. **CHECK** the installation log for error details
2. **TEST** the batch file manually
3. **VERIFY** file paths and parameters
4. **CHECK** file deployment in MSI
5. **TEST** with minimal parameters first

### When Batch Files Fail
1. **RUN** the batch file manually
2. **CHECK** all file paths
3. **VERIFY** parameter handling
4. **TEST** with sample data
5. **CHECK** error handling

## 📋 Project Code Review Checklist

### Before Submitting Any Changes
- [ ] WiX compilation succeeds
- [ ] MSI builds successfully
- [ ] All CustomActions tested
- [ ] All batch files tested manually
- [ ] File paths verified
- [ ] Registry operations tested
- [ ] WSL integration verified
- [ ] GPU detection tested
- [ ] Installation flow tested
- [ ] Uninstall process tested

## 🎯 Project Success Criteria

### A Fix is Only Complete When
1. **WiX compiles** without errors or warnings
2. **MSI builds** successfully
3. **All CustomActions** execute correctly
4. **All batch files** run without errors
5. **WSL integration** works as expected
6. **GPU detection** functions properly
7. **Installation flow** completes successfully
8. **Uninstall process** works correctly
9. **No regressions** in existing functionality

## 🚨 Project Emergency Procedures

### If WiX Won't Compile
1. **STOP** all development
2. **FIX** compilation errors first
3. **TEST** compilation after each fix
4. **ONLY THEN** proceed with other changes

### If CustomActions Fail
1. **CHECK** installation logs
2. **TEST** batch files manually
3. **VERIFY** file deployment
4. **FIX** the specific issue
5. **TEST** the fix thoroughly

### If You're Unsure
1. **STOP** and don't claim it's fixed
2. **TEST** each component individually
3. **VERIFY** each step works
4. **DOCUMENT** what you've tested
5. **ONLY THEN** declare it complete

---

## 📝 Project Quick Reference

### Essential Commands
```bash
./build.bat                           # Build MSI
msiexec /i installer.msi /l*v log    # Install with logging
msiexec /x installer.msi /l*v log    # Uninstall with logging
```

### Key Files to Check
- `installer.wxs` - Main WiX configuration
- `create_runonce.bat` - RunOnce registry creation
- `run_kamiwaza.bat` - Main installer execution
- `detect_gpu_cmd.bat` - GPU detection
- `kamiwaza_autostart.bat` - Post-reboot startup

### Critical Testing Points
- WiX compilation
- CustomAction execution
- Batch file functionality
- WSL integration
- GPU detection
- Registry operations
- File deployment
- Installation flow
- Uninstall process

---

**Remember: In this project, WiX compilation errors are CRITICAL and must be resolved before any other development can proceed.** 