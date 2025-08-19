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