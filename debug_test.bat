@echo off
echo [DEBUG] Test batch executed successfully! > "%TEMP%\kamiwaza_debug.log"
echo [DEBUG] Time: %DATE% %TIME% >> "%TEMP%\kamiwaza_debug.log"
echo [DEBUG] Working directory: %CD% >> "%TEMP%\kamiwaza_debug.log"
echo [DEBUG] Arguments: %* >> "%TEMP%\kamiwaza_debug.log"
echo [DEBUG] LOCALAPPDATA: %LOCALAPPDATA% >> "%TEMP%\kamiwaza_debug.log"
echo [DEBUG] Test completed successfully >> "%TEMP%\kamiwaza_debug.log"
echo Test batch executed - check %TEMP%\kamiwaza_debug.log