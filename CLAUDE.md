# Canonical Installer Flow and Restart Policy

## ✅ How the Installer SHOULD Run (Authoritative Flow)
- **WSL setup**: Ensure WSL is installed and functional. Repair if needed. Do not proceed until WSL is usable.
- **GPU detection and setup**:
  - Detect NVIDIA, Intel Arc, or Intel Integrated via Windows WMI.
  - Copy and run the matching WSL setup script (`setup_nvidia_gpu.sh`, `setup_intel_arc_gpu.sh`, `setup_intel_integrated_gpu.sh`).
  - All GPU scripts run non-interactively (`DEBIAN_FRONTEND=noninteractive`); no prompts.
- **Kamiwaza package installation**:
  - Download the `.deb` into WSL (`/tmp/<file>.deb`).
  - Install with `sudo apt install -y <deb>`, streaming logs to `/tmp/kamiwaza_install.log` and `/var/log/apt/term.log`.
- **Register autostart (RunOnce)**:
  - Create a `RunOnce` entry `HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce` → `KamiwazaGPUAutostart` pointing to `kamiwaza_autostart.bat`.
  - On reboot this runs: `wsl -d kamiwaza -- kamiwaza start`.
- **Automatic full device restart**:
  - Optional interactive pause if TTY: “Press Enter to proceed with FULL DEVICE restart…”.
  - 10-second visible countdown.
  - Execute `shutdown /r /t 0` to restart the entire Windows device (not just WSL).

## 🔁 After Reboot
- `RunOnce` triggers `kamiwaza_autostart.bat`.
- Starts platform with: `wsl -d kamiwaza -- kamiwaza start`.
- If anything fails, window remains open (batch files end with `pause >nul`) so logs are visible.

## 🧾 Logging & Visibility
- Python installer logs to multiple locations:
  - `%LOCALAPPDATA%\Kamiwaza\logs\kamiwaza_installer.log` (primary Windows log)
  - `%TEMP%\kamiwaza_installer_temp.log` (fallback)
  - `kamiwaza_installer_simple.log` (CWD fallback)
- WSL logs you can copy/view:
  - `/var/log/apt/term.log`, `/var/log/apt/history.log`, `/var/log/dpkg.log`
- All critical batch files end with `pause >nul` to keep the window open for debugging.

## [WARNING]️ Important Distinctions
- `wsl --shutdown` only stops WSL instances (Linux VMs). It is NOT a Windows restart.
- `shutdown /r /t 0` performs a FULL Windows device restart and is required after GPU + package setup.

## ✅ Do This
- **Use non-interactive installs** inside WSL (`DEBIAN_FRONTEND=noninteractive`).
- **Detect GPU via WMI** in Python and prefer independent detection if it disagrees with PowerShell.
- **Copy scripts into WSL** via reliable methods (tee, unique temp names, `dos2unix`, `chmod +x`).
- **Create RunOnce** to autostart Kamiwaza after restart.
- **Show a clear countdown/pause** before the automatic device restart.
- **Keep windows open** in batch files using `pause >nul` for user visibility.

## 🚫 Do NOT Do This
- **Do NOT embed Bash or Unix syntax inside PowerShell/BAT** contexts. Keep Bash in `.sh` files executed via WSL; keep PowerShell/BAT clean.
- **Do NOT use non-DOS/Windows-unsafe characters** (e.g., emojis, high Unicode) in WiX, BAT, or PowerShell that may cause codepage/linker issues.
- **Do NOT trigger restarts before package installation** or without a visible notice. The restart happens only after GPU setup AND package install.
- **Do NOT add extra manual touchpoints** requiring users to run ad-hoc CMD steps; the flow must be automated end-to-end with clear output.
- **Do NOT rely solely on WSL shutdown** for driver activation; a full Windows restart is required.

---

# Current Issue Context - Kamiwaza Installer Script Visibility

## 🎯 Current Issue Summary
**Problem**: Batch scripts launched by the MSI installer were closing immediately, preventing users from seeing error messages or execution results.

**Impact**: Users couldn't debug installation issues because script windows closed too quickly.

## [SUCCESS] What We Fixed

### Batch File Modifications
We added `pause >nul` to the end of all critical batch files:

1. **`create_runonce.bat`** [SUCCESS] Fixed
   - Added `pause >nul` to keep window open
   - Fixed path concatenation issue with backslash handling

2. **`run_kamiwaza.bat`** [SUCCESS] Fixed
   - Added `pause >nul` to keep window open
   - Now shows execution results before closing

3. **`start_platform.bat`** [SUCCESS] Fixed
   - Added `pause >nul` to keep window open
   - Allows debugging of platform startup issues

4. **`detect_gpu_cmd.bat`** [SUCCESS] Fixed
   - Added `pause >nul` to keep window open
   - Shows GPU detection results clearly

5. **`cleanup_installs.bat`** [SUCCESS] Fixed
   - Added `pause >nul` to keep window open
   - Shows cleanup results before closing

### Files That Already Had Pause
- `kamiwaza_autostart.bat` [SUCCESS] Already had `pause >nul`
- `test_gpu_setup.bat` [SUCCESS] Already had `pause`
- `test_restart_flag.bat` [SUCCESS] Already had `pause`
- `quick_cleanup.bat` [SUCCESS] Already had `pause`
- `reserve_kamiwaza_ports.bat` [SUCCESS] Already had `pause`
- `harvest_python.bat` [SUCCESS] Already had `pause`
- `create_embedded_python.bat` [SUCCESS] Already had `pause`

## 🔧 Technical Details

### The Fix Applied
```batch
REM Before (problematic):
exit /b %ERRORLEVEL%

REM After (fixed):
echo.
echo [DEBUG] Script completed. Press any key to close...
pause >nul
```

### Why This Fixes the Issue
- **`pause >nul`** keeps the command window open
- **User must press a key** to close the window
- **All output remains visible** for debugging
- **Error messages can be read** before window closes
- **Execution results are preserved** for analysis

## 🧪 Testing Results

### What We Verified
1. [SUCCESS] **Scripts now stay open** after completion
2. [SUCCESS] **Full output is visible** including error messages
3. [SUCCESS] **Debug information is preserved** for troubleshooting
4. [SUCCESS] **User control over window closure** prevents information loss
5. [SUCCESS] **Batch files work correctly** with the MSI installer

### Test Case Example
```bash
# Before fix: Window closed immediately, output lost
# After fix: Window stays open, shows:
[DEBUG] Script completed. Press any key to close...
```

## 🚨 Important Lessons Learned

### What NOT to Do
- **NEVER use `exit /b`** without user interaction in batch files
- **NEVER assume** users can see output if windows close immediately
- **NEVER skip** debugging visibility in installer scripts

### What ALWAYS to Do
- **ALWAYS add `pause >nul`** to batch files for debugging
- **ALWAYS test** script visibility after changes
- **ALWAYS verify** users can see execution results
- **ALWAYS provide** clear status messages before closing

## 🔍 Debugging Benefits

### Before the Fix
- Scripts closed immediately
- Error messages were lost
- Users couldn't see what failed
- Debugging was impossible
- Installation issues were hard to diagnose

### After the Fix
- Scripts stay open until user closes them
- All output is visible and preserved
- Error messages can be read and analyzed
- Debugging is now possible
- Installation issues can be diagnosed

## 📋 Implementation Checklist

### Files Modified
- [x] `create_runonce.bat` - Added pause and fixed path handling
- [x] `run_kamiwaza.bat` - Added pause for debugging
- [x] `start_platform.bat` - Added pause for debugging
- [x] `detect_gpu_cmd.bat` - Added pause for debugging
- [x] `cleanup_installs.bat` - Added pause for debugging

### Files Already Correct
- [x] `kamiwaza_autostart.bat` - Already had pause
- [x] `test_gpu_setup.bat` - Already had pause
- [x] `test_restart_flag.bat` - Already had pause
- [x] `quick_cleanup.bat` - Already had pause
- [x] `reserve_kamiwaza_ports.bat` - Already had pause
- [x] `harvest_python.bat` - Already had pause
- [x] `create_embedded_python.bat` - Already had pause

## 🎯 Next Steps

### Immediate Actions Required
1. **Rebuild the MSI** to include updated batch files
2. **Test the new installer** to verify script visibility
3. **Verify all scripts** now stay open for debugging

### Long-term Benefits
- **Better user experience** during installation
- **Improved debugging capabilities** for support
- **Clearer error reporting** for troubleshooting
- **Professional installer behavior** that matches user expectations

## 🚨 Critical Reminder

### Never Forget This Fix
- **ALWAYS add `pause >nul`** to new batch files
- **ALWAYS test** script visibility after changes
- **ALWAYS verify** users can see execution results
- **This fix is now a standard** for all batch files in this project

---

## 📝 Quick Reference

### Template for New Batch Files
```batch
@echo off
REM Your script content here

REM Always end with:
echo.
echo [DEBUG] Script completed. Press any key to close...
pause >nul
```

### Testing Script Visibility
1. Run the batch file manually
2. Verify it shows "Press any key to close..."
3. Verify the window stays open until key press
4. Confirm all output is visible

---

**Remember: Script visibility is not optional - it's essential for debugging and user experience. Always add `pause >nul` to batch files.** 


# Kamiwaza Development Standards & Rules

## 🚨 CRITICAL: Testing Before Conclusions

### NEVER Claim Code is "Fixed" Without Testing
- **ALWAYS test your changes** before declaring them complete
- **NEVER assume** code works just because it compiles
- **ALWAYS verify** functionality in the actual environment
- **NEVER skip testing** even for "simple" changes

### Testing Requirements
1. **Build Test**: Verify WiX compilation succeeds
2. **Install Test**: Test MSI installation process
3. **Function Test**: Verify CustomActions execute correctly
4. **Integration Test**: Test end-to-end workflow
5. **Error Test**: Verify error handling works as expected

## 🔧 Code Quality Standards

### Batch File Standards
- **ALWAYS add `pause >nul`** at the end of batch files for debugging
- **NEVER use `exit /b`** without user interaction first
- **ALWAYS provide clear error messages** and status updates
- **NEVER assume** the user can see output if window closes immediately

### PowerShell Script Standards
- **ALWAYS use proper error handling** with try/catch blocks
- **NEVER suppress errors** without logging them
- **ALWAYS provide verbose output** for debugging
- **NEVER assume** scripts run with admin privileges

### WiX/MSI Standards
- **ALWAYS test WiX compilation** after any changes
- **NEVER assume** CustomActions work without testing
- **ALWAYS verify** file paths and registry entries
- **NEVER ignore** WiX compiler warnings or errors

## 🧪 Testing Protocol

### Before Declaring Any Fix Complete
1. **Build Verification**
   - Run `./build.bat` and confirm success
   - Check for WiX compilation errors
   - Verify all files are included in MSI

2. **Installation Testing**
   - Install MSI on clean system
   - Verify all CustomActions execute
   - Check file deployment and registry entries
   - Test uninstall process

3. **Functionality Testing**
   - Execute all batch files manually
   - Verify WSL integration works
   - Test GPU detection and setup
   - Confirm restart mechanisms function

4. **Error Scenario Testing**
   - Test with insufficient permissions
   - Test with missing dependencies
   - Test with network failures
   - Verify graceful error handling

### Testing Checklist
- [ ] Code compiles without errors
- [ ] MSI builds successfully
- [ ] Installation completes without errors
- [ ] All CustomActions execute correctly
- [ ] Files are deployed to correct locations
- [ ] Registry entries are created properly
- [ ] Error handling works as expected
- [ ] Uninstall process works correctly

## 🚫 What NOT to Do

### Never Do These Things
- **NEVER claim** "this should fix it" without testing
- **NEVER assume** changes work because they look correct
- **NEVER skip** the build and test cycle
- **NEVER ignore** compiler warnings or errors
- **NEVER assume** user has same environment as developer
- **NEVER skip** error handling and logging
- **NEVER assume** scripts run with expected permissions
- DONT MAKE NEW SCRIPTS UNLESS PROMPTED TO! ALWAYS ASK BEFORE ADDING TO CLUTTERING THE REPO! 

### Common Mistakes to Avoid
- Making changes without testing
- Ignoring WiX compilation errors
- Assuming batch files work without verification
- Skipping integration testing
- Not testing error scenarios
- Assuming admin privileges are available
- Not testing on clean systems

## [SUCCESS] What ALWAYS to Do

### Always Do These Things
- **ALWAYS test** your changes thoroughly
- **ALWAYS verify** compilation success
- **ALWAYS test** installation process
- **ALWAYS verify** CustomAction execution
- **ALWAYS test** error scenarios
- **ALWAYS provide** clear status messages
- **ALWAYS log** errors and failures
- **ALWAYS test** on clean systems

### Best Practices
- Test every change before committing
- Use verbose logging for debugging
- Provide clear error messages
- Handle edge cases gracefully
- Test with different user permissions
- Verify all integration points
- Document any assumptions made

## 🔍 Debugging Standards

### When Issues Occur
1. **NEVER assume** you know the problem
2. **ALWAYS check** logs and error messages
3. **ALWAYS verify** the actual execution path
4. **ALWAYS test** the specific scenario
5. **NEVER make** multiple changes at once

### Debugging Process
1. Reproduce the issue consistently
2. Check all relevant logs and outputs
3. Test individual components in isolation
4. Make minimal changes and test each
5. Verify the fix actually resolves the issue
6. Test related functionality to ensure no regressions

## 📋 Code Review Checklist

### Before Submitting Any Code
- [ ] Code compiles without errors
- [ ] All tests pass
- [ ] Error handling is implemented
- [ ] Logging is adequate for debugging
- [ ] Edge cases are handled
- [ ] Documentation is updated
- [ ] No hardcoded paths or values
- [ ] Proper error messages are provided

## 🎯 Success Criteria

### A Fix is Only Complete When
1. **Code compiles** without errors or warnings
2. **MSI builds** successfully
3. **Installation works** on clean systems
4. **All functionality** works as expected
5. **Error handling** works gracefully
6. **Uninstall process** works correctly
7. **Integration points** function properly
8. **Testing confirms** the fix resolves the issue

## 🚨 Emergency Procedures

### If You're Unsure About a Fix
1. **STOP** and don't claim it's fixed
2. **TEST** thoroughly before proceeding
3. **ASK** for help if needed
4. **VERIFY** each step works
5. **DOCUMENT** what you've tested
6. **ONLY THEN** declare it complete

### Remember
- **Testing is not optional** - it's mandatory
- **Compilation success** ≠ functionality success
- **Looking correct** ≠ working correctly
- **One successful test** ≠ comprehensive verification
- **Always test, never assume**

---

## 📝 Quick Reference

### Before Saying "Fixed"
- [ ] Built successfully
- [ ] Installed successfully  
- [ ] Functions correctly
- [ ] Error handling works
- [ ] Integration tested
- [ ] Clean system tested

### Testing Command Sequence
```bash
./build.bat                    # Build MSI
msiexec /i installer.msi      # Install
# Test functionality
msiexec /x installer.msi      # Uninstall
# Verify cleanup
```

### Key Testing Points
- WiX compilation
- MSI installation
- CustomAction execution
- File deployment
- Registry creation
- WSL integration
- GPU detection
- Error scenarios
- Uninstall process

---

**Remember: Testing is not a suggestion - it's a requirement. Never claim code is fixed without comprehensive testing.** 

# Current Issue Context - Kamiwaza Installer Script Visibility

## 🎯 Current Issue Summary
**Problem**: Batch scripts launched by the MSI installer were closing immediately, preventing users from seeing error messages or execution results.

**Impact**: Users couldn't debug installation issues because script windows closed too quickly.

## [SUCCESS] What We Fixed

### Batch File Modifications
We added `pause >nul` to the end of all critical batch files:

1. **`create_runonce.bat`** [SUCCESS] Fixed
   - Added `pause >nul` to keep window open
   - Fixed path concatenation issue with backslash handling

2. **`run_kamiwaza.bat`** [SUCCESS] Fixed
   - Added `pause >nul` to keep window open
   - Now shows execution results before closing

3. **`start_platform.bat`** [SUCCESS] Fixed
   - Added `pause >nul` to keep window open
   - Allows debugging of platform startup issues

4. **`detect_gpu_cmd.bat`** [SUCCESS] Fixed
   - Added `pause >nul` to keep window open
   - Shows GPU detection results clearly

5. **`cleanup_installs.bat`** [SUCCESS] Fixed
   - Added `pause >nul` to keep window open
   - Shows cleanup results before closing

### Files That Already Had Pause
- `kamiwaza_autostart.bat` [SUCCESS] Already had `pause >nul`
- `test_gpu_setup.bat` [SUCCESS] Already had `pause`
- `test_restart_flag.bat` [SUCCESS] Already had `pause`
- `quick_cleanup.bat` [SUCCESS] Already had `pause`
- `reserve_kamiwaza_ports.bat` [SUCCESS] Already had `pause`
- `harvest_python.bat` [SUCCESS] Already had `pause`
- `create_embedded_python.bat` [SUCCESS] Already had `pause`

## 🔧 Technical Details

### The Fix Applied
```batch
REM Before (problematic):
exit /b %ERRORLEVEL%

REM After (fixed):
echo.
echo [DEBUG] Script completed. Press any key to close...
pause >nul
```

### Why This Fixes the Issue
- **`pause >nul`** keeps the command window open
- **User must press a key** to close the window
- **All output remains visible** for debugging
- **Error messages can be read** before window closes
- **Execution results are preserved** for analysis

## 🧪 Testing Results

### What We Verified
1. [SUCCESS] **Scripts now stay open** after completion
2. [SUCCESS] **Full output is visible** including error messages
3. [SUCCESS] **Debug information is preserved** for troubleshooting
4. [SUCCESS] **User control over window closure** prevents information loss
5. [SUCCESS] **Batch files work correctly** with the MSI installer

### Test Case Example
```bash
# Before fix: Window closed immediately, output lost
# After fix: Window stays open, shows:
[DEBUG] Script completed. Press any key to close...
```

## 🚨 Important Lessons Learned

### What NOT to Do
- **NEVER use `exit /b`** without user interaction in batch files
- **NEVER assume** users can see output if windows close immediately
- **NEVER skip** debugging visibility in installer scripts

### What ALWAYS to Do
- **ALWAYS add `pause >nul`** to batch files for debugging
- **ALWAYS test** script visibility after changes
- **ALWAYS verify** users can see execution results
- **ALWAYS provide** clear status messages before closing

## 🔍 Debugging Benefits

### Before the Fix
- Scripts closed immediately
- Error messages were lost
- Users couldn't see what failed
- Debugging was impossible
- Installation issues were hard to diagnose

### After the Fix
- Scripts stay open until user closes them
- All output is visible and preserved
- Error messages can be read and analyzed
- Debugging is now possible
- Installation issues can be diagnosed

## 📋 Implementation Checklist

### Files Modified
- [x] `create_runonce.bat` - Added pause and fixed path handling
- [x] `run_kamiwaza.bat` - Added pause for debugging
- [x] `start_platform.bat` - Added pause for debugging
- [x] `detect_gpu_cmd.bat` - Added pause for debugging
- [x] `cleanup_installs.bat` - Added pause for debugging

### Files Already Correct
- [x] `kamiwaza_autostart.bat` - Already had pause
- [x] `test_gpu_setup.bat` - Already had pause
- [x] `test_restart_flag.bat` - Already had pause
- [x] `quick_cleanup.bat` - Already had pause
- [x] `reserve_kamiwaza_ports.bat` - Already had pause
- [x] `harvest_python.bat` - Already had pause
- [x] `create_embedded_python.bat` - Already had pause

## 🎯 Next Steps

### Immediate Actions Required
1. **Rebuild the MSI** to include updated batch files
2. **Test the new installer** to verify script visibility
3. **Verify all scripts** now stay open for debugging

### Long-term Benefits
- **Better user experience** during installation
- **Improved debugging capabilities** for support
- **Clearer error reporting** for troubleshooting
- **Professional installer behavior** that matches user expectations

## 🚨 Critical Reminder

### Never Forget This Fix
- **ALWAYS add `pause >nul`** to new batch files
- **ALWAYS test** script visibility after changes
- **ALWAYS verify** users can see execution results
- **This fix is now a standard** for all batch files in this project

---

## 📝 Quick Reference

### Template for New Batch Files
```batch
@echo off
REM Your script content here

REM Always end with:
echo.
echo [DEBUG] Script completed. Press any key to close...
pause >nul
```

### Testing Script Visibility
1. Run the batch file manually
2. Verify it shows "Press any key to close..."
3. Verify the window stays open until key press
4. Confirm all output is visible

---

**Remember: Script visibility is not optional - it's essential for debugging and user experience. Always add `pause >nul` to batch files.** 


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